# Contributing to Labs

Thank you for your interest in contributing to our labs monorepo! This document outlines the process for contributing to this project.

## Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR-USERNAME/labs.git`
3. Add the upstream repository: `git remote add upstream https://github.com/allinbits/labs.git`
4. Create a new branch for your changes: `git checkout -b feature/your-feature-name`

## Development Workflow

### Project Structure

Please respect the monorepo structure:

- `cmd/`: Command-line applications
- `pkg/`: Shared libraries and utilities
- `projects/`: Lab experiments and projects
- `scripts/`: Build, test, and automation scripts

### Adding a New Project

New lab experiments should be added under the `projects/` directory with a clear README explaining:

- Purpose and goals
- How to run/test
- Dependencies
- Current status

## Code Standards

- Write clear, commented code
- Follow the established patterns in the codebase
- Include appropriate tests for new functionality
- Update documentation as needed

## Pull Request Process

1. Ensure your code passes all tests
2. Update the README.md if needed
3. Create a pull request against the main branch
4. Reference any related issues in your PR description
5. Wait for review from maintainers

## Issue Reporting

When reporting issues, please include:

- A clear description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- Environment details (OS, Go version, etc.)

## License

By contributing, you agree that your contributions will be licensed under the project's license.
