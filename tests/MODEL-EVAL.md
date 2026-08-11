# Local-model release evaluation

This suite qualifies actual model work, not wrapper mechanics. A scenario passes only
when the local model creates the required repository diff and an independent hidden
oracle verifies the result after the model run.

The hidden oracle is stored outside the fixture while the model works. It is copied or
invoked only after the workflow ends, so the model cannot implement directly against
the release assertions. Model-written reports and model-invoked test output are never
accepted as substitutes for the oracle.

Coverage includes bug fixing, feature implementation, behavior-preserving refactoring,
repository analysis/document generation, JavaScript, Python, Java, and PowerShell.

