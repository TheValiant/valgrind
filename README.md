# Untested yet

## Install

Copy and paste this single command to install:

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/macgrind/main/install.sh | bash
```

##  Usage

After installation, restart terminal/source rc files, then use Valgrind normally:

```bash
valgrind --tool=memcheck your_program
valgrind --tool=memcheck --leak-check=full ./your_app
```
