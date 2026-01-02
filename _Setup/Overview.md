# Setup

Technical configuration files for running the analysis.

## Files

- **requirements.txt** — Python package dependencies

## Installation

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install Python packages
pip install -r _Setup/requirements.txt

# R packages (run in R console)
install.packages(c("lavaan", "semTools", "mice", "parallel"))
```
