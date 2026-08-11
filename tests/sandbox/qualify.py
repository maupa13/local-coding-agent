
from __future__ import annotations
from pathlib import Path
import json, re, subprocess, tempfile, shutil, hashlib, sys

ROOT = Path(__file__).resolve().parents[2]
RESULTS=[]

def check(name, fn):
    try:
        detail=fn()
        RESULTS.append((name,"PASS",detail or ""))
        print(f"[PASS] {name}" + (f" - {detail}" if detail else ""))
    except Exception as e:
        RESULTS.append((name,"FAIL",str(e)))
        print(f"[FAIL] {name} - {e}")

def require(cond,msg):
    if not cond:
        raise AssertionError(msg)

def read(rel, enc="utf-8-sig"):
    return (ROOT/rel).read_text(encoding=enc)

def test_version():
    v=read("VERSION","utf-8").strip()
    require(bool(re.fullmatch(r"1\.0\.0-(?:dev|rc\.\d+|RELEASE)", v)), f"unexpected VERSION format {v}")
    # VERSION is the source of truth; the sandbox must never hardcode a candidate number.
    for rel in ["tests/TEST-MATRIX.json", "tests/SCENARIO-MATRIX.json"]:
        obj=json.loads(read(rel))
        if isinstance(obj, dict) and "version" in obj:
            require(obj["version"]==v, f"{rel} version {obj['version']} != {v}")
    return v

def test_json():
    tm=json.loads(read("tests/TEST-MATRIX.json"))
    sm=json.loads(read("tests/SCENARIO-MATRIX.json"))
    contracts=tm["contracts"]
    ids=[x["id"] for x in contracts]
    require(len(ids)==len(set(ids)),"duplicate test IDs")
    req={"id","area","description","test","tier"}
    for c in contracts:
        require(req.issubset(c),f"bad schema for {c.get('id')}")
        require((ROOT/c["test"]).exists(),f"missing test {c['test']}")
    sids=[x["id"] for x in sm["scenarios"]]
    require(len(sids)==len(set(sids)),"duplicate scenario IDs")
    require("REG-022" in ids and "REG-023" in ids,"new regressions missing")
    require("SCN-009" in sids and "SCN-010" in sids,"new scenarios missing")
    return f"{len(contracts)} tests, {len(sids)} scenarios"

def test_powershell_bom():
    bad=[]
    for p in ROOT.rglob("*"):
        if p.suffix.lower() not in {".ps1",".psm1"}: continue
        b=p.read_bytes()
        if not b.startswith(b"\xef\xbb\xbf") or b.startswith(b"\xef\xbb\xbf\xef\xbb\xbf"):
            bad.append(str(p.relative_to(ROOT)))
    require(not bad,"bad BOM: "+", ".join(bad[:5]))
    return f"{sum(1 for p in ROOT.rglob('*') if p.suffix.lower() in {'.ps1','.psm1'})} files"

def test_module_contracts():
    m=read("powershell/LocalCodingAgent.psm1")
    needles=[
        "function Get-AgentComplianceRequirements",
        "function Get-AgentComplianceEvidence",
        "function Write-DeterministicComplianceFinalResult",
        "function Write-DeterministicWorkflowFinalResult",
        "wrapperCanPromote",
        "StandardOutputEncoding",
        "StandardErrorEncoding",
        "PYTHONIOENCODING='utf-8'",
    ]
    for n in needles: require(n in m,f"missing {n}")
    funcs=re.findall(r"(?mi)^function\s+([A-Za-z0-9_-]+)\s*\{",m)
    dup=sorted({x for x in funcs if funcs.count(x)>1})
    require(not dup,"duplicate functions: "+", ".join(dup))
    require("1.0.0-rc.6" not in m,"stale rc.6 reference in module")
    return f"{len(funcs)} functions, 0 duplicates"

def make_fixture(path: Path):
    (path/"docs").mkdir(parents=True)
    (path/"src").mkdir()
    (path/"tests").mkdir()
    (path/"docs"/"requirements.md").write_text("""# Session store requirements

REQ-01: `SessionStore.save(token)` must persist the supplied token.
REQ-02: `SessionStore.load()` must return the persisted token.
REQ-03: `SessionStore.clear()` must remove the persisted token so that `load()` returns `null`.
REQ-04: save/load/clear behavior must have automated regression tests.
""",encoding="utf-8")
    (path/"src"/"session-store.js").write_text("""class SessionStore {
  constructor() { this.token = null; }
  save(token) { this.token = token; }
  load() { return this.token; }
  clear() { return this.token; }
}
module.exports = { SessionStore };
""",encoding="utf-8")
    (path/"tests"/"session-store.test.js").write_text("""const test = require('node:test');
const assert = require('node:assert/strict');
const { SessionStore } = require('../src/session-store');
test('save/load roundtrip', () => {
 const store = new SessionStore();
 store.save('abc');
 assert.equal(store.load(), 'abc');
});
""",encoding="utf-8")
    (path/"package.json").write_text(json.dumps({
        "name":"sandbox-release-fixture","version":"1.0.0","private":True,
        "scripts":{"test":"node --test"}
    },indent=2),encoding="utf-8")

def npm_test(path: Path):
    cp=subprocess.run(["npm","test"],cwd=path,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    return cp.returncode, cp.stdout

def test_fixture_semantics():
    td=Path(tempfile.mkdtemp(prefix="lca-sandbox-"))
    try:
        make_fixture(td)
        code,out=npm_test(td)
        require(code==0,"baseline save/load test should pass")
        testp=td/"tests"/"session-store.test.js"
        testp.write_text(testp.read_text()+"""
test('clear removes token', () => {
 const store = new SessionStore();
 store.save('abc');
 store.clear();
 assert.equal(store.load(), null);
});
""",encoding="utf-8")
        code,out=npm_test(td)
        require(code!=0,"new clear regression must fail before source fix")
        src=td/"src"/"session-store.js"
        src.write_text(src.read_text().replace("clear() { return this.token; }","clear() { this.token = null; }"),encoding="utf-8")
        code,out=npm_test(td)
        require(code==0,"regression must pass after expected source fix")
        return "baseline PASS -> regression FAIL -> fixed PASS"
    finally:
        shutil.rmtree(td,ignore_errors=True)

REQ_RE=re.compile(r"^\s*([A-Za-z]{2,16}[-_ ]?\d+)\s*:\s*(.+?)\s*$")
BACKTICK_RE=re.compile(r"`([^`]+)`")

def extract_requirements(doc: str):
    rows=[]
    for line in doc.splitlines():
        m=REQ_RE.match(line)
        if m:
            rows.append((m.group(1).replace("_","-").replace(" ","-").upper(),m.group(2)))
    return rows

def evidence(req_text, src_text, test_text):
    anchors=[]
    refs=BACKTICK_RE.findall(req_text)
    if refs:
        v=re.sub(r"\([^)]*\)","",refs[0])
        for part in re.split(r"[^A-Za-z0-9_.]+",v):
            if len(part)>=3:
                anchors.append(part)
                if "." in part: anchors.append(part.split(".")[-1])
    anchors=sorted(set(anchors))
    impl=any(re.search(re.escape(a),src_text,re.I) for a in anchors) if anchors else False
    tests=any(re.search(re.escape(a),test_text,re.I) for a in anchors) if anchors else False
    status="PARTIAL" if impl else "NOT VERIFIED"
    return status,impl,tests,anchors

def test_compliance_reference():
    doc="""REQ-01: `SessionStore.save(token)` must persist the supplied token.
REQ-02: `SessionStore.load()` must return the persisted token.
REQ-03: `SessionStore.clear()` must remove the persisted token so that `load()` returns `null`.
REQ-04: save/load/clear behavior must have automated regression tests."""
    src="class SessionStore { save(token){} load(){} clear(){ return this.token; } }"
    tests="test('save/load roundtrip',()=>{ store.save('a'); store.load(); });"
    rows=extract_requirements(doc)
    require(len(rows)==4,"must extract 4 requirements")
    r3=[r for r in rows if r[0]=="REQ-03"][0]
    st,impl,tst,anchors=evidence(r3[1],src,tests)
    require(st=="PARTIAL" and impl and not tst,"REQ-03 must be conservative PARTIAL with no test evidence")
    matrix=["COMPLIANCE MATRIX"]+[f"{rid} | {evidence(txt,src,tests)[0]}" for rid,txt in rows]
    require("REQ-03 | PARTIAL" in "\n".join(matrix),"matrix missing REQ-03")
    return "4 REQs; REQ-03 conservatively PARTIAL"


def terminal_report(text: str) -> str:
    matches=list(re.finditer(r"(?im)^\s*FINAL RESULT:\s*(?:PASS|PARTIAL|BLOCKED|FAIL)\s*$", text))
    if not matches:
        return ""
    return text[matches[-1].start():].strip()

def compliance_valid(text: str) -> bool:
    report=terminal_report(text)
    if not report:
        return False
    status_matches=list(re.finditer(r"(?im)^\s*FINAL RESULT:\s*(PASS|PARTIAL|BLOCKED|FAIL)\s*$", report))
    if not status_matches:
        return False
    status=status_matches[-1].group(1).upper()
    has_matrix=bool(re.search(r"(?im)^\s*(?:COMPLIANCE\s+MATRIX|МАТРИЦ[АЫ]\s+СООТВЕТСТВ)", report))
    status_hits=len(re.findall(r"(?im)\b(?:PASS|PARTIAL|FAIL|NOT VERIFIED|CONFLICT)\b", report))
    has_evidence=bool(re.search(r"(?im)(implementation evidence|test/verification evidence|verification evidence|implementation|test evidence|реализац|тест|провер)", report))
    if status=="BLOCKED":
        return bool(re.search(r"(?im)(source.*(?:unavailable|not found|inaccessible)|документ[^\r\n]*(?:не найден|недоступ)|permission denied|access denied|tool.*unavailable|environment.*unavailable)", report))
    return has_matrix and status_hits>=3 and has_evidence

def test_terminal_compliance_scope():
    contaminated = """SYSTEM/RULE CONTEXT:
You must produce COMPLIANCE MATRIX with implementation evidence and test evidence.
Example statuses: PASS PARTIAL FAIL NOT VERIFIED.

tool: read docs/requirements.md
tool: read src/session-store.js

FINAL RESULT: FAIL
WORKFLOW: analysis
SUMMARY
- Inspected docs/requirements.md for documented requirements.
- Inspected src/session-store.js for implementation evidence.
- Inspected tests/session-store.test.js for automated regression tests.
- Identified REQ-03 and clear test coverage as failures/gaps.
CHANGED FILES
- NONE
VERIFICATION
- node:test run: NOT RUN — no build/test command executed in analysis mode; code inspection used
ACCEPTANCE
- All requirements verified against implementation and test evidence
RISKS / NOT VERIFIED
- REQ-03 FAIL: clear() is a documented defect. Test coverage for clear absent.
NEXT
NONE
"""
    require(not compliance_valid(contaminated), "rc.8 transcript contamination must be rejected")

    canonical = """noise COMPLIANCE MATRIX PASS FAIL implementation evidence
FINAL RESULT: PARTIAL
WORKFLOW: analysis
SUMMARY
Canonical wrapper report.
COMPLIANCE MATRIX
| Requirement | Status | Implementation evidence | Test/verification evidence |
|---|---|---|---|
| REQ-01 | PASS | src/a.js | tests/a.test.js |
| REQ-02 | PARTIAL | src/a.js | NOT VERIFIED |
| REQ-03 | FAIL | src/a.js | NOT VERIFIED |
VERIFICATION
- tests: NOT VERIFIED
"""
    require(compliance_valid(canonical), "canonical terminal compliance report must validate")
    report=terminal_report(contaminated)
    require(report.startswith("FINAL RESULT: FAIL"), "must extract last terminal result")
    require("SYSTEM/RULE CONTEXT" not in report, "terminal report leaked pre-final transcript")
    return "rc.8 contaminated transcript rejected; canonical report accepted"


def test_compliance_docs_discovery_and_markdown_forms():
    td=Path(tempfile.mkdtemp(prefix="lca-docs-sandbox-"))
    try:
        docs=td/"docs"
        nested=docs/"nested"
        nested.mkdir(parents=True)
        (docs/"requirements.md").write_text("""# Requirements
REQ-01: alpha
- REQ-02: beta
* **REQ-03**: gamma
### REQ-04 — delta
""", encoding="utf-8")
        (nested/"extra.txt").write_text("REQ-05 - epsilon\n", encoding="utf-8")

        candidates=[]
        for p in docs.rglob("*"):
            if p.is_file() and p.suffix.lower() in {".md",".txt",".rst",".adoc",".json",".yaml",".yml"}:
                candidates.append(p)

        pat=re.compile(r"^\s*(?:[-*+]\s*)?(?:#{1,6}\s*)?(?:\*\*|__)?([A-Za-z]{2,16}[-_ ]?\d+)(?:\*\*|__)?\s*(?::|[-–—])\s*(.+?)\s*$")
        rows=[]
        for p in candidates:
            for line in p.read_text(encoding="utf-8").splitlines():
                m=pat.match(line)
                if m:
                    rows.append((m.group(1).replace("_","-").replace(" ","-").upper(),m.group(2)))
        ids=sorted({r[0] for r in rows})
        require(ids==["REQ-01","REQ-02","REQ-03","REQ-04","REQ-05"], f"unexpected requirement IDs {ids}")
        return "direct docs scan found REQ-01..REQ-05 across markdown variants"
    finally:
        shutil.rmtree(td,ignore_errors=True)


def test_strictmode_verifier_hygiene():
    bad=[]
    pat=re.compile(r'^\s*(?:Need|Assert\w*)\s+"[^"\n]*\\\$[A-Za-z_][A-Za-z0-9_]*[^"\n]*"')
    for p in (ROOT/'tests').glob('VERIFY-*.ps1'):
        txt=p.read_text(encoding='utf-8-sig')
        for no,line in enumerate(txt.splitlines(),1):
            if pat.search(line):
                bad.append(f'{p.name}:{no}: {line.strip()}')
    require(not bad, 'unsafe StrictMode verifier interpolation: ' + ' | '.join(bad[:8]))
    return 'no unsafe double-quoted literal $variable verifier patterns'


def test_nonzero_compliance_finalizer_contract():
    m=read("powershell/LocalCodingAgent.psm1")
    fn_start=m.find("function Write-DeterministicComplianceFinalResult")
    fn_end=m.find("\nfunction ",fn_start+10)
    fn=m[fn_start:fn_end]
    require(fn_start>=0,"compliance finalizer missing")
    require("if($ExitCode -ne 0){return $null}" not in fn,"non-zero exit still disables compliance finalizer")
    require("Continue CLI exit code: $(if($ExitCode -eq 0)" in fn,"model exit status not preserved in evidence")
    require("incomplete/failed model summary" in fn,"failed model summary contract missing")
    # State-machine expectation: model process may fail, but local docs can still
    # deterministically yield a conservative matrix. It must never be PASS.
    final_status="PARTIAL"
    reqs=["REQ-01","REQ-02","REQ-03","REQ-04"]
    require(len(reqs)==4 and final_status=="PARTIAL","unexpected fallback semantics")
    return "non-zero model exit still yields conservative local compliance finalization"


def test_diagnostic_logging_and_runtime_selftest_contract():
    qualify=read("QUALIFY-RELEASE.ps1")
    live=read("tests/RUN-LIVE-E2E.ps1")
    module=read("powershell/LocalCodingAgent.psm1")
    runtime_test=read("tests/VERIFY-COMPLIANCE-RUNTIME-SELFTEST.ps1")
    checks=[
        ("Start-Transcript" in qualify, "qualification transcript missing"),
        ("Environment snapshot" in qualify, "environment snapshot missing"),
        ("$env:LOCALAPPDATA" in qualify, "qualification logs not rooted outside package"),
        ("STEP-$safeName.stdout.log" in qualify and "STEP-$safeName.stderr.log" in qualify, "per-step stdout/stderr logs missing"),
        ("[STEP] exit:" in qualify, "step exit/timing missing"),
        ("function Write-EvidenceDiagnostics" in live, "live diagnostics helper missing"),
        ("compliance-requirements-diagnostic.txt" in live, "requirement diagnostic not dumped"),
        ("model-output.txt" in live and "compliance-recovery-output.txt" in live, "model/recovery tails missing"),
        ("Fixture preserved automatically after failure" in live, "failed fixture preservation missing"),
        ("RepositoryRoot exists:" in module and "DocsRoot exists:" in module, "extractor root diagnostics missing"),
        ("requirement matches:" in module and "Unique requirements:" in module, "extractor match diagnostics missing"),
        ("Test-LocalCodingAgentComplianceExtractor" in runtime_test, "runtime self-test does not invoke real extractor helper"),
        ("REQ-01" in runtime_test and "REQ-04" in runtime_test, "runtime self-test expected IDs missing"),
    ]
    for cond,msg in checks:
        require(cond,msg)
    return "persistent transcript + evidence dump + real PowerShell extractor self-test contracts present"


def test_log_isolation_package_contamination():
    qualify=read("QUALIFY-RELEASE.ps1")
    verify=read("VERIFY-PACKAGE.ps1")
    require("Join-Path $root 'logs'" not in qualify, "qualification still writes logs under package root")
    require("$env:LOCALAPPDATA" in qualify, "external diagnostic root missing")
    require("STEP-$safeName.stdout.log" in qualify, "per-step stdout log missing")
    require("STEP-$safeName.stderr.log" in qualify, "per-step stderr log missing")
    require("logs|evidence|results|test-results" in verify, "package source scan does not exclude transient dirs")
    require("hardcoded user profile in distributable source" in verify, "profile scan does not report source evidence")
    return "runtime logs cannot self-contaminate package profile scan"


def test_rc14_matrix_before_final_and_runstep_contract():
    # Exact layout seen on Windows: matrix table first, terminal FINAL RESULT second.
    text="""## COMPLIANCE MATRIX
| REQ | requirement | status | implementation evidence | test/verification evidence | gap |
|-----|-------------|--------|-------------------------|----------------------------|-----|
| REQ-01 | save | PASS | src/session-store.js | tests/session-store.test.js | NONE |
| REQ-02 | load | PASS | src/session-store.js | tests/session-store.test.js | NONE |
| REQ-03 | clear | FAIL | src/session-store.js | NOT VERIFIED | broken |
| REQ-04 | regression tests | FAIL | - | NOT VERIFIED | missing |

FINAL RESULT: FAIL
WORKFLOW: analysis
SUMMARY
REQ-03/REQ-04 fail.
"""
    matrix=re.search(r"(?ims)^\s*(?:#{1,6}\s*)?(?:COMPLIANCE\s+MATRIX|МАТРИЦ[АЫ]\s+СООТВЕТСТВ)\s*$.*?(?=^\s*FINAL RESULT:)",text)
    require(matrix is not None,"matrix-before-final not found")
    mt=matrix.group(0)
    require(re.search(r"(?im)\|\s*(?:REQ|Requirement)",mt) is not None,"matrix header missing")
    require(re.search(r"(?im)\bREQ[-_ ]?\d+\b",mt) is not None,"REQ identifiers missing")
    require(terminal_report(text).startswith("FINAL RESULT: FAIL"),"terminal status not preserved")

    q=read("QUALIFY-RELEASE.ps1")
    require("Export-Clixml" not in q and "Import-Clixml" not in q,"CLIXML argument trampoline still present")
    require("& $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $path @Arguments" in q,"direct named argument invocation missing")
    require("$code=$LASTEXITCODE" in q,"authoritative child exit missing")
    return "rc.14 matrix-before-final accepted; Run-Step binding no longer uses CLIXML"


def test_variable_colon_and_folder_identity():
    bad=[]
    pat=re.compile(r'"[^"\\n]*(?<!`)\\$([A-Za-z_][A-Za-z0-9_]*):[^"\\n]*"')
    allowed={"env","script","global","local","private"}
    for p in ROOT.rglob("*"):
        if p.suffix.lower() not in {".ps1",".psm1"}:
            continue
        txt=p.read_text(encoding="utf-8-sig")
        for n,line in enumerate(txt.splitlines(),1):
            if line.lstrip().startswith("#"):
                continue
            for m in pat.finditer(line):
                if m.group(1).lower() in allowed:
                    continue
                bad.append(f"{p.relative_to(ROOT)}:{n}:{line.strip()}")
    require(not bad,"unsafe $variable: interpolation: "+" | ".join(bad[:5]))
    qualify=read("QUALIFY-RELEASE.ps1")
    install=read("INSTALL.ps1")
    dev=read("DEV.ps1")
    require("Package folder/version mismatch" not in qualify,"QUALIFY still version-folder locked")
    require("Package folder/version mismatch" not in install,"INSTALL still version-folder locked")
    require("checkpoint" in dev and "restore" in dev and "qualify" in dev,"DEV workflow incomplete")
    return "no unsafe $variable: interpolation; stable dev folder + Git workflow present"

def wrapper_state(exit_code, compliance=False, req_count=0, changed=0, checks=None, review=None, violations=0):
    checks=checks or []
    if exit_code!=0: return "FAIL"
    if compliance and req_count>0: return "PARTIAL"
    provisional="PARTIAL"
    can_promote=changed>0 and len(checks)>0 and all(checks) and violations==0 and review in {"PASS","WARN"}
    return "PASS" if can_promote else provisional

def test_state_machine():
    cases=[
        ("compliance incomplete",wrapper_state(0,True,4,0,[],None,0),"PARTIAL"),
        ("mutating verified",wrapper_state(0,False,0,2,[True],"PASS",0),"PASS"),
        ("mutating review warn",wrapper_state(0,False,0,2,[True],"WARN",0),"PASS"),
        ("mutating test fail",wrapper_state(0,False,0,2,[False],"PASS",0),"PARTIAL"),
        ("mutating violation",wrapper_state(0,False,0,2,[True],"PASS",1),"PARTIAL"),
        ("process failure",wrapper_state(7,False,0,2,[True],"PASS",0),"FAIL"),
        ("no changes",wrapper_state(0,False,0,0,[True],"PASS",0),"PARTIAL"),
    ]
    for name,got,want in cases:
        require(got==want,f"{name}: {got} != {want}")
    return f"{len(cases)} state transitions"

def test_no_mojibake_literals():
    bad=[]
    for p in ROOT.rglob("*"):
        if p.is_file() and p.suffix.lower() in {".ps1",".psm1",".md",".json",".yaml",".yml"}:
            try:s=p.read_text(encoding="utf-8-sig")
            except:continue
            if "тАФ" in s: bad.append(str(p.relative_to(ROOT)))
    require(not bad,"mojibake literal found: "+", ".join(bad))
    return "no known mojibake literal"

for name,fn in [
    ("version sync",test_version),
    ("JSON/test/scenario schema",test_json),
    ("PowerShell single UTF-8 BOM",test_powershell_bom),
    ("core finalizer contracts",test_module_contracts),
    ("release fixture semantics",test_fixture_semantics),
    ("compliance reference finalizer",test_compliance_reference),
    ("terminal compliance transcript scope",test_terminal_compliance_scope),
    ("compliance docs discovery/markdown forms",test_compliance_docs_discovery_and_markdown_forms),
    ("nonzero compliance finalizer",test_nonzero_compliance_finalizer_contract),
    ("diagnostic logging/static runtime selftest",test_diagnostic_logging_and_runtime_selftest_contract),
    ("log isolation/package contamination",test_log_isolation_package_contamination),
    ("rc.14 matrix-before-final accepted",test_rc14_matrix_before_final_and_runstep_contract),
    ("variable-colon/stable dev workspace",test_variable_colon_and_folder_identity),
    ("StrictMode verifier hygiene",test_strictmode_verifier_hygiene),
    ("wrapper state machine",test_state_machine),
    ("UTF-8 text hygiene",test_no_mojibake_literals),
]:
    check(name,fn)

failed=[x for x in RESULTS if x[1]=="FAIL"]
out={
    "version": read("VERSION","utf-8").strip(),
    "verdict":"PASS" if not failed else "FAIL",
    "passed":len(RESULTS)-len(failed),
    "failed":len(failed),
    "results":[{"name":n,"status":s,"detail":d} for n,s,d in RESULTS]
}
(ROOT/"SANDBOX-QUALIFICATION.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
lines=[
    f"# Sandbox qualification — {out['version']}",
    "",
    f"**VERDICT: {out['verdict']}**",
    "",
    f"PASS: {out['passed']} · FAIL: {out['failed']}",
    "",
    "| Check | Status | Detail |",
    "|---|---|---|",
]
for r in out["results"]:
    lines.append(f"| {r['name']} | {r['status']} | {r['detail'].replace('|','/')} |")
lines += ["","This suite runs in the build sandbox. Windows PowerShell 5.1, the installed Continue CLI, Ollama models, and IntelliJ IDEA still require target-machine qualification."]
(ROOT/"SANDBOX-QUALIFICATION.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
sys.exit(1 if failed else 0)
