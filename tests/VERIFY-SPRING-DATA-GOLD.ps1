[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$toolchains=Get-Content (Join-Path $root 'config\toolchains.json') -Raw|ConvertFrom-Json
$javaHome=[string]$toolchains.java.javaHome
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-spring-data-'+[guid]::NewGuid().ToString('N'))
$versions=@(@{line='2';version='2.7.18';persistence='javax.persistence'},@{line='3';version='3.5.16';persistence='jakarta.persistence'},@{line='4';version='4.0.7';persistence='jakarta.persistence'})
try{
  foreach($item in $versions){
    $project=Join-Path $tmp ('boot-'+$item.line);New-Item -ItemType Directory -Force (Join-Path $project 'src\main\java\eval'),(Join-Path $project 'src\test\java\eval')|Out-Null
    @"
<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion><parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>$($item.version)</version><relativePath/></parent><groupId>eval</groupId><artifactId>spring-data-$($item.line)</artifactId><version>1</version><properties><java.version>21</java.version></properties><dependencies><dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency><dependency><groupId>com.h2database</groupId><artifactId>h2</artifactId><scope>runtime</scope></dependency><dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency></dependencies></project>
"@|Set-Content -Encoding ASCII (Join-Path $project 'pom.xml')
    'package eval; import org.springframework.boot.autoconfigure.SpringBootApplication; @SpringBootApplication public class App {}'|Set-Content -Encoding ASCII (Join-Path $project 'src\main\java\eval\App.java')
    @"
package eval;
import $($item.persistence).*;
@Entity @Table(name="accounts", uniqueConstraints=@UniqueConstraint(name="uk_accounts_email",columnNames="email"))
public class Account {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @Column(nullable=false) private String email;
 protected Account() {}
 public Account(String email){this.email=email;}
 public Long getId(){return id;} public String getEmail(){return email;}
}
"@|Set-Content -Encoding ASCII (Join-Path $project 'src\main\java\eval\Account.java')
    'package eval; import java.util.Optional; import org.springframework.data.jpa.repository.JpaRepository; public interface AccountRepository extends JpaRepository<Account,Long>{Optional<Account> findByEmail(String email);}'|Set-Content -Encoding ASCII (Join-Path $project 'src\main\java\eval\AccountRepository.java')
    @'
package eval;
import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;
@SpringBootTest @Transactional class AccountRepositoryTest {
 @Autowired AccountRepository repository;
 @BeforeEach void clean(){repository.deleteAll();repository.flush();}
 @Test void persistsAndQueries(){Account saved=repository.saveAndFlush(new Account("a@example.test"));assertNotNull(saved.getId());assertEquals(saved.getId(),repository.findByEmail("a@example.test").orElseThrow().getId());}
 @Test void enforcesSqlUniqueConstraint(){repository.saveAndFlush(new Account("same@example.test"));assertThrows(DataIntegrityViolationException.class,()->repository.saveAndFlush(new Account("same@example.test")));}
 @Test void startsIsolated(){assertEquals(0,repository.count());}
}
'@|Set-Content -Encoding ASCII (Join-Path $project 'src\test\java\eval\AccountRepositoryTest.java')
    Push-Location $project
    try{
      $saved=$env:JAVA_HOME;$env:JAVA_HOME=$javaHome;$savedPreference=$ErrorActionPreference;$ErrorActionPreference='Continue'
      $mavenOutput=@(& mvn.cmd -q test 2>&1|ForEach-Object{[string]$_});$mavenExit=$LASTEXITCODE;$ErrorActionPreference=$savedPreference
      if($mavenExit -ne 0){$mavenOutput|Write-Host;throw "[FAIL] Spring Boot $($item.version) SQL/JPA/Hibernate"}
    }finally{$ErrorActionPreference=$savedPreference;$env:JAVA_HOME=$saved;Pop-Location}
  }
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host '[PASS] Spring Boot 2/3/4 SQL, JPA, Hibernate and transaction gold gates on Temurin 21' -ForegroundColor Green




