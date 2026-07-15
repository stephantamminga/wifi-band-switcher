
# 🧠 Copilot Instructions for Python Projects

Welcome to this Python codebase! This guide is for GitHub Copilot or any AI assistant contributing to this project. Please follow the **SOLID principles** and Pythonic best practices to ensure clean, maintainable, and scalable code.

---

## 🧱 General Python Guidelines

- Follow **PEP 8** for code style and formatting.
- Use **type hints** for all function signatures.
- Prefer **dataclasses** for simple data containers.
- Use **docstrings** (PEP 257) for all public classes and methods.
- Avoid global state and side effects.
- Use **virtual environments** and manage dependencies with `requirements.txt` or `pyproject.toml`.
- In `requirements.txt` and `pyproject.toml`, specify exact versions to ensure reproducibility.
- Provide **code annotations** for complex logic to improve understanding.
- Display a progress indicator for long-running tasks.

---

## 📚 Preferred Libraries

Preferably use the following libraries for common tasks, but you can deviate if necessary:

- **Graphical interface**: PyQt
- **Fancy plots and graphs**: plotly
- **Simple plots and graphs**: matplotlib, bokeh
- **Data manipulation**: pandas
- **Progress indicator**: tqdm. Make sure to use tqdm.write to print messages without disrupting the progress bar.
- When dealing with equations, use `sympy` for symbolic mathematics

Do NOT use these packages when it can be avoided, as they are abandoned or have a slow development cycle:

- **Plots and graphs**: seaborn (use plotly, matplotlib, or bokeh instead)
- **Graphical interface**: EasyGUI (use PyQt instead)
- **Image processing**: PIL (use Pillow instead)

Always check for the latest versions of libraries and prefer those that are actively maintained. If a library is no longer maintained, look for a well-supported alternative.
WARN if the last release is more than 1 year old, as this may indicate the library is no longer maintained.

---

## 🧩 SOLID Principles in Python

### 1. **Single Responsibility Principle (SRP)**

- Each class or function should do **one thing only**.
- Split logic into smaller, testable components.
- ✅ Good: `UserValidator`, `UserRepository`, and `UserService` are separate classes.

### 2. **Open/Closed Principle (OCP)**

- Use **abstract base classes** (`abc.ABC`) or **protocols** (`typing.Protocol`) to define extensible behavior.
- Avoid modifying existing classes to add new features—extend them instead.
- ✅ Good: Add new serializers by subclassing `BaseSerializer`.

### 3. **Liskov Substitution Principle (LSP)**

- Subclasses should be usable anywhere their parent class is expected.
- Avoid overriding methods in a way that breaks expectations.
- ✅ Good: `FileLogger` and `ConsoleLogger` both implement `Logger` and behave consistently.

### 4. **Interface Segregation Principle (ISP)**

- Define **small, focused interfaces** using abstract base classes or protocols.
- Avoid forcing classes to implement unused methods.
- ✅ Good: Separate `Readable`, `Writable`, and `Serializable` interfaces.

### 5. **Dependency Inversion Principle (DIP)**

- Depend on **abstractions**, not concrete implementations.
- Use **constructor injection** or **dependency injection frameworks** (e.g., `dependency-injector`).
- ✅ Good: Inject a `NotificationService` into `UserService` instead of instantiating it directly.

---

## ✅ Copilot Code Review Checklist

Before suggesting code, ensure:

- [ ] SOLID principles are followed.
- [ ] Type hints are used.
- [ ] Code is modular and testable.
- [ ] No hardcoded dependencies.
- [ ] Unit tests are included or updated.
- [ ] Code is formatted with `black` or `ruff`.
- [ ] Docstrings are clear and informative.
- [ ] All docstrings include pseudo-code.

---

## 🧪 Testing Guidelines

- Use `pytest` for testing.
- Place tests in a `tests/` directory mirroring the source structure.
- Use **fixtures** and **mocks** for setup and isolation.
- Aim for **high test coverage** and meaningful assertions.

---

## 📁 Project Structure

\`\`\`
project/
│
├── src/
│   ├── services/
│   ├── interfaces/
│   ├── models/
│   └── utils/
│
├── tests/
│   └── unit/
│
├── requirements.txt
└── pyproject.toml
\`\`\`

---

## 🗂️ File Handling

- When dealing with files, use context managers (`with open(...) as ...:`) to ensure proper resource management.
- When dealing with csv files, prefer using the `csv` module or `pandas` for reading and writing.
- When dealing with csv files, prefer using `;` as a delimiter to avoid issues with commas in data.
- Always validate file paths and handle exceptions gracefully (e.g., `FileNotFoundError`, `PermissionError`).
- Prefer pathlib (`from pathlib import Path`) for file and directory operations for better cross-platform compatibility.
- Avoid hardcoding file paths; use configuration files or environment variables.
- When writing files, ensure atomic writes (e.g., write to a temp file and move/rename) to prevent data corruption.
- For large files, process data in chunks to avoid high memory usage.
- Sanitize and validate user-supplied filenames to prevent security issues.
- When serializing data (e.g., JSON, YAML), use safe loaders/dumpers and handle encoding explicitly.
- When dealing with measurement files, prefer using tdms files for large datasets, as they are efficient and support metadata.
