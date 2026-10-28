"""Run the original Python DISCO implementation (Beer et al.) on one dataset.

Usage: python disco_python_run.py <reference_repo> <data.csv> <scores_out.csv>

<data.csv> has columns x1..xp and label (-1 = noise).
Prints:  RESULT impl=python sklearn=<real|numpy> n=<n> score=<mean> disco_time_s=<seconds>

Only disco.py and dcdistances/dctree.py of the reference repository are
loaded; src/Evaluation/__init__.py is bypassed because it imports every other
validity index in the repository.

The reference code uses three scikit-learn functions: pairwise_distances
(Euclidean), KDTree(X).query(X, k) and silhouette_samples(metric="precomputed").
On macOS 27 the compiled scipy modules that scikit-learn loads at start-up
cannot be opened by the system linker. In that case the three functions are
replaced by NumPy implementations of the same formulas, and the output line
says sklearn=numpy. All DISCO-specific code remains the authors' original.
Set DISCO_FORCE_NUMPY=1 to use the NumPy versions even when scikit-learn works.
"""
import importlib.util
import os
import sys
import time
import traceback
import types

import numpy as np


# ---------------------------------------------------------------------------
# NumPy versions of the three scikit-learn functions used by the reference code
def _pairwise_distances(X, Y=None, metric="euclidean", n_jobs=None, **kwargs):
    if metric != "euclidean":
        raise ValueError("only metric='euclidean' is supported")
    X = np.asarray(X, dtype=float)
    same = Y is None
    Y = X if same else np.asarray(Y, dtype=float)
    # same formula as sklearn.metrics.euclidean_distances
    XX = np.einsum("ij,ij->i", X, X)[:, None]
    YY = np.einsum("ij,ij->i", Y, Y)[None, :]
    D = -2.0 * (X @ Y.T)
    D += XX
    D += YY
    np.maximum(D, 0, out=D)
    if same:
        np.fill_diagonal(D, 0)
    return np.sqrt(D, out=D)


class _KDTree:
    """Exact brute-force replacement for sklearn.neighbors.KDTree (query only)."""

    def __init__(self, X, **kwargs):
        self.X = np.asarray(X, dtype=float)

    def query(self, Q, k=1, chunk=512):
        Q = np.asarray(Q, dtype=float)
        dist = np.empty((len(Q), k))
        ind = np.empty((len(Q), k), dtype=int)
        for s in range(0, len(Q), chunk):
            q = Q[s:s + chunk]
            d = np.sqrt(((q[:, None, :] - self.X[None, :, :]) ** 2).sum(-1))
            part = np.argpartition(d, k - 1, axis=1)[:, :k]
            dp = np.take_along_axis(d, part, axis=1)
            order = np.argsort(dp, axis=1, kind="stable")
            dist[s:s + chunk] = np.take_along_axis(dp, order, axis=1)
            ind[s:s + chunk] = np.take_along_axis(part, order, axis=1)
        return dist, ind


def _silhouette_samples(X, labels, metric="precomputed", **kwargs):
    if metric != "precomputed":
        raise ValueError("only metric='precomputed' is supported")
    D = np.asarray(X, dtype=float)
    _, lab = np.unique(np.asarray(labels), return_inverse=True)
    n, K = len(lab), lab.max() + 1
    freq = np.bincount(lab, minlength=K)
    M = np.zeros((n, K))
    M[np.arange(n), lab] = 1.0
    S = D @ M                                      # sum of distances to each cluster
    own = S[np.arange(n), lab]
    with np.errstate(divide="ignore", invalid="ignore"):
        intra = own / (freq[lab] - 1)              # nan for singleton clusters
        mean = S / freq
        mean[np.arange(n), lab] = np.inf
        inter = mean.min(axis=1)
        sil = (inter - intra) / np.maximum(intra, inter)
    return np.nan_to_num(sil)                      # singleton clusters -> 0, as sklearn


def _install_numpy_sklearn():
    for name in list(sys.modules):
        if name == "sklearn" or name.startswith("sklearn.") or name == "scipy" or name.startswith("scipy."):
            del sys.modules[name]
    sk = types.ModuleType("sklearn"); sk.__path__ = []
    metrics = types.ModuleType("sklearn.metrics")
    metrics.pairwise_distances = _pairwise_distances
    metrics.silhouette_samples = _silhouette_samples
    neighbors = types.ModuleType("sklearn.neighbors")
    neighbors.KDTree = _KDTree
    sys.modules.update({"sklearn": sk, "sklearn.metrics": metrics, "sklearn.neighbors": neighbors})


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


try:
    repo, data_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    ev = os.path.join(repo, "src", "Evaluation")

    backend = "real"
    if os.environ.get("DISCO_FORCE_NUMPY") == "1":
        backend = "numpy"
    else:
        try:
            import sklearn.metrics    # noqa: F401
            import sklearn.neighbors  # noqa: F401
        except ImportError:
            backend = "numpy"
    if backend == "numpy":
        _install_numpy_sklearn()

    # empty package stubs, so that "from src.Evaluation.dcdistances.dctree import DCTree"
    # in disco.py resolves without running the packages' __init__ files
    for pkg in ["src", "src.Evaluation", "src.Evaluation.dcdistances"]:
        stub = types.ModuleType(pkg)
        stub.__path__ = []
        sys.modules[pkg] = stub
    load_module("src.Evaluation.dcdistances.dctree", os.path.join(ev, "dcdistances", "dctree.py"))
    disco = load_module("src.Evaluation.disco", os.path.join(ev, "disco.py"))

    data = np.genfromtxt(data_path, delimiter=",", names=True)
    cols = [c for c in data.dtype.names if c != "label"]
    X = np.column_stack([data[c] for c in cols]).astype(float)
    labels = data["label"].astype(int)

    t0 = time.perf_counter()
    scores = disco.disco_samples(X, labels, min_points=5)
    t = time.perf_counter() - t0

    np.savetxt(out_path, scores, delimiter=",", header="score", comments="")
    print(f"RESULT impl=python sklearn={backend} n={len(X)} "
          f"score={np.mean(scores):.15f} disco_time_s={t:.4f}")
except Exception:
    print("PYERROR " + traceback.format_exc().strip().replace("\n", " || "))
    sys.exit(1)
