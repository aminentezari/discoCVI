#include <Rcpp.h>
#include <cmath>
#include <vector>
using namespace Rcpp;

// Prim's minimum spanning tree on mutual-reachability distances,
//   d_reach(i, j) = max(core[i], core[j], ||x_i - x_j||),
// computed on the fly so that no n x n matrix is ever stored.
// Time O(n^2 p), memory O(n).
//
// Xt   : the TRANSPOSED data matrix (p x n), so each point is contiguous.
// core : core distances (length n).
// Returns the n - 1 MST edges with 1-based endpoints.
// [[Rcpp::export(.prim_mrd_cpp)]]
List prim_mrd_cpp(NumericMatrix Xt, NumericVector core) {
  const int p = Xt.nrow(), n = Xt.ncol();
  std::vector<double> d(n, R_PosInf);
  std::vector<int> par(n, -1);
  std::vector<char> in_tree(n, 0);
  IntegerVector ei(n > 0 ? n - 1 : 0), ej(n > 0 ? n - 1 : 0);
  NumericVector ew(n > 0 ? n - 1 : 0);
  if (n == 0) return List::create(_["i"] = ei, _["j"] = ej, _["dist"] = ew);

  d[0] = 0.0;
  int m = 0;
  for (int step = 0; step < n; ++step) {
    if ((step & 1023) == 0) Rcpp::checkUserInterrupt();
    int v = -1;
    double best = R_PosInf;
    for (int j = 0; j < n; ++j) {
      if (in_tree[j]) continue;
      if (v < 0 || d[j] < best) { best = d[j]; v = j; }
    }
    in_tree[v] = 1;
    if (par[v] >= 0) { ei[m] = par[v] + 1; ej[m] = v + 1; ew[m] = d[v]; ++m; }
    const double* xv = &Xt(0, v);
    const double cv = core[v];
    for (int j = 0; j < n; ++j) {
      if (in_tree[j]) continue;
      const double* xj = &Xt(0, j);
      double s = 0.0;
      for (int c = 0; c < p; ++c) { const double t = xv[c] - xj[c]; s += t * t; }
      double r = std::sqrt(s);
      if (cv > r) r = cv;
      if (core[j] > r) r = core[j];
      if (r < d[j]) { d[j] = r; par[j] = v; }
    }
  }
  return List::create(_["i"] = ei, _["j"] = ej, _["dist"] = ew);
}
