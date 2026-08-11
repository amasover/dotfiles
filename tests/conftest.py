"""Shared pytest helpers for the vm-harness Python tools."""

import importlib.machinery
import importlib.util
from pathlib import Path

_SETUP_DIR = Path(__file__).parent.parent / ".local" / "bin" / "setup"


def load_tool(module_name: str, filename: str):
    """Import an extension-less script under .local/bin/setup as a module."""
    loader = importlib.machinery.SourceFileLoader(module_name, str(_SETUP_DIR / filename))
    spec = importlib.util.spec_from_loader(module_name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod
