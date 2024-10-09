# Cookiecutter Python: Modern Python Project Template

A modern Python project template with best practices for development, testing,
and deployment.

## Features

- Python 3.12 support
- Docker containerization
- Comprehensive Makefile for common tasks
- Code formatting with Black, isort, and Prettier
- Linting with Flake8
- Type checking with MyPy
- Security scanning with Bandit
- Dependency management with pip-tools
- Git hooks with pre-commit
- Conventional Commits with Commitizen
- VS Code configuration
- Continuous Integration ready

## Prerequisites

- Python 3.12+
- Docker
- Make
- Node.js and npm (for some development tools)
- Homebrew (for macOS users)

## Getting Started

1. Clone the repository:

   ```sh
   git clone https://github.com/yourusername/cookiecutter-python.git
   cd cookiecutter-python
   ```

2. Set up the development environment:

   ```sh
   make install
   ```

   This will:

   - Create a virtual environment
   - Install Python dependencies
   - Install Node.js dependencies
   - Set up git hooks
   - Install Homebrew dependencies (if on macOS)

3. Virtual Environment Activation:

   The project uses direnv and the .envrc file to automatically activate the
   virtual environment when you enter the project directory. There's no need to
   manually activate it.

## Development

- Format code:

  ```sh
  make format
  ```

- Run linters:

  ```sh
  make lint
  ```

- Scan for vulnerabilities:

  ```sh
  make scan
  ```

- Build Docker image:

  ```sh
  make build
  ```

- Run the application:

  ```sh
  make start
  ```

## Project Structure

## Additional Information
