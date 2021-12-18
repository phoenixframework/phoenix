:: batch file used in Phoenix watcher test. serves 2 purposes:
:: 1. polyfills the watcher test's use of `echo`, which isn't 
::    an executable on windows but an internal command
:: 2. verifies that the watcher code can launch batch files on windows.
@echo %*