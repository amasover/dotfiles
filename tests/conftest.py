"""Shared pytest helpers for the vm-harness Python tools."""

import importlib.machinery
import importlib.util
from pathlib import Path

_BIN_DIR = Path(__file__).parent.parent / ".local" / "bin"


def load_tool(module_name: str, filename: str, subdir: str = "setup"):
    """Import an extension-less script under .local/bin/<subdir> as a module."""
    loader = importlib.machinery.SourceFileLoader(module_name, str(_BIN_DIR / subdir / filename))
    spec = importlib.util.spec_from_loader(module_name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod
