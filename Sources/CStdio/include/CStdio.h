#include <stdio.h>

// Glibc declares stdout and stderr as mutable globals, which Swift 6 rejects; these accessors are the same on every platform.
static inline FILE *periphery_stdout(void) { return stdout; }
static inline FILE *periphery_stderr(void) { return stderr; }
