\documentclass[11pt, a4paper]{article}

% ── Packages ──────────────────────────────────────────────────────────────────
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{lmodern}
\usepackage{geometry}
\usepackage{amsmath, amssymb}
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{array}
\usepackage{parskip}
\usepackage{xcolor}
\usepackage{listings}
\usepackage{hyperref}
\usepackage{titlesec}
\usepackage{enumitem}
\usepackage{fancyhdr}
\usepackage{microtype}

\geometry{
  top    = 2.5cm,
  bottom = 2.5cm,
  left   = 2.8cm,
  right  = 2.8cm
}

% ── Colours ───────────────────────────────────────────────────────────────────
\definecolor{codeblue}{RGB}{30, 100, 180}
\definecolor{codegray}{RGB}{90, 90, 90}
\definecolor{backgray}{RGB}{248, 248, 248}
\definecolor{ruleblue}{RGB}{20, 70, 140}
\definecolor{goodgreen}{RGB}{20, 120, 60}
\definecolor{softred}{RGB}{180, 50, 50}
\definecolor{softorange}{RGB}{200, 120, 20}
\definecolor{diffred}{RGB}{220,40,40}
\definecolor{difforange}{RGB}{240,140,0}

% ── Listings style (R code) ───────────────────────────────────────────────────
\lstdefinestyle{Rstyle}{
  language        = R,
  backgroundcolor = \color{backgray},
  basicstyle      = \ttfamily\small,
  keywordstyle    = \color{codeblue}\bfseries,
  commentstyle    = \color{codegray}\itshape,
  stringstyle     = \color{codeblue!70},
  breaklines      = true,
  frame           = single,
  framerule       = 0.4pt,
  rulecolor       = \color{ruleblue!40},
  xleftmargin     = 0.5em,
  xrightmargin    = 0.5em,
  aboveskip       = 0.6em,
  belowskip       = 0.6em,
}
\lstset{style=Rstyle}

% ── Section formatting ────────────────────────────────────────────────────────
\titleformat{\section}[block]
  {\large\bfseries\color{ruleblue}}
  {\thesection.}{0.5em}{}
  [\vspace{-0.3em}\rule{\linewidth}{1.2pt}]

\titleformat{\subsection}[block]
  {\normalsize\bfseries\color{ruleblue!80}}
  {\thesubsection}{0.5em}{}

% ── Header / footer ───────────────────────────────────────────────────────────
\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0.4pt}
\fancyhead[L]{\small\textit{disco} --- Function Reference}
\fancyhead[R]{\small\thepage}

% ── Convenience command for function signatures ───────────────────────────────
\newcommand{\funcsig}[1]{%
  \vspace{0.4em}
  \lstinline[basicstyle=\ttfamily\normalsize\color{codeblue}\bfseries]{#1}%
  \vspace{0.2em}
}

% ── Argument table environment ────────────────────────────────────────────────
\newenvironment{argtable}{%
  \vspace{0.4em}
  \begin{longtable}{>{\ttfamily}p{3.2cm} p{2.2cm} p{8.6cm}}
  \toprule
  \normalfont\textbf{Argument} & \textbf{Type} & \textbf{Description} \\
  \midrule
  \endfirsthead
  \toprule
  \normalfont\textbf{Argument} & \textbf{Type} & \textbf{Description} \\
  \midrule
  \endhead
  \bottomrule
  \endlastfoot
}{%
  \end{longtable}
  \vspace{0.2em}
}

\newcommand{\diffval}[1]{%
  \begingroup
  \ifdim #1pt < 0.000000000001pt
    \textcolor{goodgreen}{\textbf{#1}}
  \else
    \textcolor{softorange}{\textbf{#1}}
  \fi
  \endgroup
}

% =============================================================================
\begin{document}
% =============================================================================

\begin{titlepage}
  \centering
  \vspace*{3cm}
  {\Huge\bfseries\color{ruleblue} disco}\par
  \vspace{0.6em}
  {\large Density-Informed Clustering Scoring\\[0.2em] and Optimisation}\par
  \vspace{1.2em}
  {\large Function Reference Manual}\par
  \vspace{2em}
  \rule{10cm}{1pt}\par
  \vspace{1.5em}
  {\normalsize R Package \texttt{disco} --- CRAN Release}\par
  \vspace{0.6em}
  {\normalsize\today}\par
  \vfill
\end{titlepage}

\tableofcontents
\clearpage

% =============================================================================
\section{Package Overview}
% =============================================================================

The \textbf{disco} package provides the \emph{DISCO} (Density-Informed
Clustering Scoring and Optimisation) evaluation metric for clustering results.
DISCO generalises the silhouette coefficient to density-based partitions and
extends naturally to noise/outlier points, as produced by algorithms such as
DBSCAN and HDBSCAN.

All scores lie in $[-1, 1]$:
\begin{itemize}[leftmargin=2em]
  \item $+1$ indicates a perfectly placed point (tight cluster membership or a
        noise point legitimately far from all clusters).
  \item $\phantom{+}0$ indicates a borderline point.
  \item $-1$ indicates a misplaced point (wrong cluster or a noise point that
        should be inside a cluster).
\end{itemize}

The package exposes \textbf{eight functions} divided into two layers:

\begin{center}
\begin{tabular}{llp{7cm}}
\toprule
\textbf{Layer} & \textbf{Function} & \textbf{Role} \\
\midrule
Public API & \texttt{disco\_score}   & Scalar DISCO quality measure \\
           & \texttt{disco\_samples} & Per-point DISCO scores \\
           & \texttt{p\_cluster}     & Silhouette via DC distances \\
           & \texttt{p\_noise}       & Quality scores for noise points \\
           & \texttt{compute\_dc\_distances} & Full DC-distance matrix \\
\midrule
Internal   & \texttt{calculate\_reachability\_distance} & Mutual-reachability matrix \\
           & \texttt{get\_mst\_edges}                   & Prim's MST \\
           & \texttt{extract\_dc\_distances\_from\_mst} & BFS minimax path \\
\bottomrule
\end{tabular}
\end{center}

\subsection{Dependencies}

\begin{itemize}[leftmargin=2em]
  \item \texttt{FNN} --- fast $k$-nearest-neighbour search (\texttt{get.knn}).
  \item \texttt{stats} (base R) --- Euclidean distance matrix (\texttt{dist}).
\end{itemize}

% =============================================================================
\section{Public API}
% =============================================================================

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{disco\_score}}
\label{sec:disco_score}

\subsubsection*{Description}
Returns a single scalar summarising overall clustering quality.  Internally it
calls \texttt{disco\_samples} and returns the arithmetic mean of the per-point
scores.  This is the primary metric for model selection and hyperparameter
optimisation.

\subsubsection*{Usage}
\begin{lstlisting}
disco_score(X, labels, min_points = 5)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
X          & matrix / data.frame & Numeric data matrix of shape $n \times p$. \\
labels     & integer vector      & Cluster labels of length $n$. Use \texttt{-1} for noise/outlier points. \\
min\_points & integer             & Core-distance neighbourhood size ($k = \text{min\_points} - 1$). Must be $\geq 2$. Default: \texttt{5}. \\
\end{argtable}

\subsubsection*{Value}
A single \texttt{numeric} value in $[-1, 1]$.

\subsubsection*{Examples}
\begin{lstlisting}
set.seed(42)
X <- matrix(rnorm(100), ncol = 2)
labels <- rep(c(0L, 1L), each = 25)
disco_score(X, labels)
\end{lstlisting}

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{disco\_samples}}
\label{sec:disco_samples}

\subsubsection*{Description}
Computes a per-point DISCO score for every observation.  Four cases are handled
based on the composition of \texttt{labels}:

\begin{enumerate}[leftmargin=2em]
  \item \textbf{All noise} (every label is \texttt{-1}): all scores are
        $-1$.
  \item \textbf{Single cluster, no noise} (one unique label $\neq -1$): all
        scores are $0$.
  \item \textbf{One real cluster + noise points}: cluster points are scored
        by \texttt{p\_cluster}; noise points by \texttt{p\_noise}.
  \item \textbf{Two or more real clusters (optional noise)}: non-noise points
        are scored by \texttt{p\_cluster} on the non-noise DC-distance
        sub-matrix; noise points by \texttt{p\_noise}.
\end{enumerate}

\subsubsection*{Usage}
\begin{lstlisting}
disco_samples(X, labels, min_points = 5)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
X          & matrix / data.frame & Numeric data matrix of shape $n \times p$. \\
labels     & integer vector      & Cluster labels of length $n$; \texttt{-1} denotes noise. \\
min\_points & integer             & Core-distance neighbourhood size. Must be $\geq 2$. Default: \texttt{5}. \\
\end{argtable}

\subsubsection*{Value}
A \texttt{numeric} vector of length $n$ with per-point DISCO scores in
$[-1, 1]$.

\subsubsection*{See Also}
\texttt{disco\_score} (\S\ref{sec:disco_score}),
\texttt{p\_cluster} (\S\ref{sec:p_cluster}),
\texttt{p\_noise} (\S\ref{sec:p_noise}).

\subsubsection*{Examples}
\begin{lstlisting}
set.seed(42)
X <- matrix(rnorm(100), ncol = 2)
labels <- rep(c(0L, 1L), each = 25)
s <- disco_samples(X, labels)
hist(s, main = "Per-sample DISCO scores")
\end{lstlisting}

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{p\_cluster}}
\label{sec:p_cluster}

\subsubsection*{Description}
Computes a density-aware silhouette coefficient for each point using
DC distances in place of raw Euclidean distances.  This matches the formula
used by \texttt{sklearn\-.metrics\-.silhouette\_samples} with
\texttt{metric="precomputed"} (Python reference: \texttt{disco.py}, line 280).

For each point $i$ with label $c_i$:
\begin{align}
  a(i) &= \frac{1}{|C_{c_i}|-1}\sum_{j \in C_{c_i},\, j \neq i}
           d_{\text{DC}}(i,j) \label{eq:a}\\[4pt]
  b(i) &= \min_{c \neq c_i}\;\frac{1}{|C_c|}
           \sum_{j \in C_c} d_{\text{DC}}(i,j) \label{eq:b}\\[4pt]
  s(i) &= \frac{b(i) - a(i)}{\max\bigl(a(i),\, b(i)\bigr)} \label{eq:s}
\end{align}
where $d_{\text{DC}}$ denotes the density-connectivity distance.

\subsubsection*{Usage}
\begin{lstlisting}
p_cluster(X, labels, min_points = 5, precomputed_dc_dists = FALSE)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
X                    & matrix              & Either raw data ($n \times p$) or a precomputed DC-distance matrix ($n \times n$), depending on \texttt{precomputed\_dc\_dists}. \\
labels               & integer vector      & Cluster labels of length $n$. Should not contain \texttt{-1} noise labels. \\
min\_points           & integer             & Used only when \texttt{precomputed\_dc\_dists = FALSE}. Must be $\geq 2$. Default: \texttt{5}. \\
precomputed\_dc\_dists & logical             & If \texttt{TRUE}, \texttt{X} is treated as an already-computed DC-distance matrix. Default: \texttt{FALSE}. \\
\end{argtable}

\subsubsection*{Value}
A \texttt{numeric} vector of length $n$ with silhouette-style scores in
$[-1, 1]$.

Special cases:
\begin{itemize}[leftmargin=2em]
  \item Empty input: returns \texttt{numeric(0)}.
  \item Single point: returns \texttt{0}.
  \item All points in one cluster \textbf{or} each point in its own cluster:
        returns a vector of zeros.
\end{itemize}

\subsubsection*{Examples}
\begin{lstlisting}
set.seed(7)
X <- matrix(rnorm(60), ncol = 2)
labels <- rep(c(0L, 1L, 2L), each = 10)
p_cluster(X, labels)
\end{lstlisting}

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{p\_noise}}
\label{sec:p_noise}

\subsubsection*{Description}
Assigns a quality score to each noise point (label \texttt{-1}).  Two
sub-scores are computed; the element-wise minimum becomes the final score
(returned as a list so callers can inspect both components):

\paragraph{Sparsity score $p_{\text{sparse}}$}
Tests whether the noise point is less dense than the densest part of every
real cluster.  Let $M_c = \max_{j \in C_c} \text{core}_k(j)$ be the maximum
core distance in cluster $c$.  Then:
\[
  p_{\text{sparse}}(i) = \min_{c}\;
    \frac{\text{core}_k(i) - M_c}{\max\!\bigl(\text{core}_k(i),\, M_c\bigr)}
\]

\paragraph{Distance score $p_{\text{far}}$}
Tests whether the noise point is far from every cluster in DC-distance space.
Let $d_{\min,c}(i) = \min_{j \in C_c} d_{\text{DC}}(i,j)$.  Then:
\[
  p_{\text{far}}(i) = \min_{c}\;
    \frac{d_{\min,c}(i) - M_c}{\max\!\bigl(d_{\min,c}(i),\, M_c\bigr)}
\]

Both scores lie in $[-1, 1]$.  A positive value means the noise point is
legitimately sparse or far; a negative value means it is denser/closer than
the cluster boundary and is likely a misclassified inlier.

\subsubsection*{Usage}
\begin{lstlisting}
p_noise(X, labels, min_points = 5, dc_dists = NULL)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
X          & matrix / data.frame & All $n$ points (including non-noise). \\
labels     & integer vector      & Labels of length $n$; \texttt{-1} marks noise. \\
min\_points & integer             & Core-distance neighbourhood size. Must be $\geq 2$. Default: \texttt{5}. \\
dc\_dists   & matrix or NULL      & Optional precomputed $n \times n$ DC-distance matrix. Computed internally if \texttt{NULL}. Default: \texttt{NULL}. \\
\end{argtable}

\subsubsection*{Value}
A named \texttt{list} with two components:
\begin{itemize}[leftmargin=2em]
  \item \texttt{p\_sparse} --- numeric vector (length = number of noise points)
        with sparsity-based scores.
  \item \texttt{p\_far} --- numeric vector (length = number of noise points)
        with DC-distance-based scores.
\end{itemize}

Special cases:
\begin{itemize}[leftmargin=2em]
  \item All labels are \texttt{-1}: both components are \texttt{rep(-1, n)}.
  \item No noise labels: both components are \texttt{numeric(0)}.
\end{itemize}

\subsubsection*{Examples}
\begin{lstlisting}
set.seed(3)
X <- matrix(rnorm(60), ncol = 2)
labels <- c(rep(0L, 20), rep(1L, 20), rep(-1L, 10))
nr <- p_noise(X, labels, min_points = 5)
str(nr)
\end{lstlisting}

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{compute\_dc\_distances}}
\label{sec:compute_dc_distances}

\subsubsection*{Description}
The main entry point for constructing the full DC-distance matrix.  The
procedure follows three steps:

\begin{enumerate}[leftmargin=2em]
  \item \textbf{Mutual-reachability distances} ---
        $d_{\text{reach}}(i,j) = \max\bigl(\text{core}_k(i),\;
        \text{core}_k(j),\; d(i,j)\bigr)$ (see
        \S\ref{sec:calc_reach}).
  \item \textbf{Minimum spanning tree} --- Prim's algorithm on the
        mutual-reachability matrix (see \S\ref{sec:get_mst}).
  \item \textbf{Minimax-path extraction} --- BFS over the MST; the DC
        distance between two points equals the heaviest edge on the path
        connecting them in the MST (see \S\ref{sec:extract_dc}).
\end{enumerate}

\subsubsection*{Usage}
\begin{lstlisting}
compute_dc_distances(X, min_points = 5)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
X          & matrix / data.frame & Numeric data matrix of shape $n \times p$. \\
min\_points & integer             & Core-distance neighbourhood size. Must be $\geq 2$. Default: \texttt{5}. \\
\end{argtable}

\subsubsection*{Value}
A symmetric $n \times n$ \texttt{numeric} matrix of DC distances with zeros on
the diagonal.  Returns a $0 \times 0$ matrix for empty input and a $1 \times 1$
zero matrix for a single point.

\subsubsection*{Examples}
\begin{lstlisting}
set.seed(1)
X <- matrix(rnorm(40), ncol = 2)
D <- compute_dc_distances(X, min_points = 5)
dim(D)   # 20 x 20
\end{lstlisting}

% =============================================================================
\section{Internal Functions}
% =============================================================================

These functions are not exported but are documented here for contributors and
for transparency about the algorithmic pipeline.

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{calculate\_reachability\_distance}}
\label{sec:calc_reach}

\subsubsection*{Description}
Computes the $n \times n$ mutual-reachability distance matrix.  For each pair
$(i, j)$:
\[
  d_{\text{reach}}(i,j) =
    \max\bigl(\text{core}_k(i),\;\text{core}_k(j),\;d_{\text{Eucl}}(i,j)\bigr)
\]
where $\text{core}_k(i)$ is the distance from $i$ to its $k$-th nearest
neighbour ($k = \text{min\_points} - 1$), computed via \texttt{FNN::get.knn}
(self excluded).  This matches Python's
\texttt{np.partition(row, k)[:k].max()} idiom (reference:
\texttt{dctree.py}, lines 704--713).

\subsubsection*{Usage (internal)}
\begin{lstlisting}
calculate_reachability_distance(points, min_points = 5)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
points     & matrix  & $n \times p$ numeric matrix. \\
min\_points & integer & Neighbourhood size. Must be $\geq 2$. Default: \texttt{5}. \\
\end{argtable}

\subsubsection*{Value}
A symmetric $n \times n$ \texttt{numeric} matrix with zeros on the diagonal.

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{get\_mst\_edges}}
\label{sec:get_mst}

\subsubsection*{Description}
Implements Prim's algorithm to find the minimum spanning tree of a fully
connected weighted graph represented by \texttt{dist\_matrix}.  The
implementation mirrors \texttt{dctree.py} lines 401--438 exactly (0-indexed
Python $\to$ 1-indexed R).

\begin{enumerate}[leftmargin=2em]
  \item Initialise: $d_{\min}[u=1] \leftarrow 0$; all others $\leftarrow
        \infty$; $u=1$ marked as \emph{in MST}.
  \item Repeat $n-1$ times:
  \begin{enumerate}[label=\alph*.]
    \item Update $d_{\min}[v]$ and $\text{parent}[v]$ for all $v \notin
          \text{MST}$ where $\text{dist}[u,v] < d_{\min}[v]$.
    \item Select the not-yet-included node $u^*$ with smallest $d_{\min}$.
    \item Record edge $(\text{parent}[u^*], u^*, d_{\min}[u^*])$.
    \item Mark $u^*$ as \emph{in MST}.
  \end{enumerate}
\end{enumerate}

\subsubsection*{Usage (internal)}
\begin{lstlisting}
get_mst_edges(dist_matrix)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
dist\_matrix & matrix & Symmetric $n \times n$ distance matrix. \\
\end{argtable}

\subsubsection*{Value}
A \texttt{data.frame} with $n-1$ rows and columns \texttt{i} (integer),
\texttt{j} (integer), \texttt{dist} (numeric).

% ─────────────────────────────────────────────────────────────────────────────
\subsection{\texttt{extract\_dc\_distances\_from\_mst}}
\label{sec:extract_dc}

\subsubsection*{Description}
Given the MST edge list, computes the pairwise DC-distance matrix via
breadth-first search (BFS).  For each source node \texttt{start}, BFS
propagates the running maximum edge weight along each tree path:
\[
  d_{\text{DC}}(\text{start}, v) =
    \max_{\text{edges on path}(\text{start} \to v)} w_e
\]
This is the \emph{minimax path} (bottleneck shortest-path) in the MST.

\subsubsection*{Usage (internal)}
\begin{lstlisting}
extract_dc_distances_from_mst(mst_edges, n)
\end{lstlisting}

\subsubsection*{Arguments}
\begin{argtable}
mst\_edges & data.frame & Edge list with columns \texttt{i}, \texttt{j}, \texttt{dist} (output of \texttt{get\_mst\_edges}). \\
n          & integer    & Total number of points. \\
\end{argtable}

\subsubsection*{Value}
A symmetric $n \times n$ \texttt{numeric} DC-distance matrix.

% =============================================================================
\section{Algorithmic Summary}
% =============================================================================

\begin{center}
\begin{tabular}{cl}
\toprule
\textbf{Step} & \textbf{Operation} \\
\midrule
1 & Euclidean pairwise distances $d(i,j)$ \\
2 & Core distances $\text{core}_k(i)$ via $k$-NN ($k = \text{min\_points} - 1$) \\
3 & Mutual-reachability matrix
    $d_{\text{reach}}(i,j) = \max(\text{core}_k(i), \text{core}_k(j), d(i,j))$ \\
4 & MST of $d_{\text{reach}}$ via Prim's algorithm \\
5 & DC-distance matrix: minimax path weight in MST \\
6 & Silhouette on DC distances for cluster points \\
7 & Sparsity / far-distance scores for noise points \\
8 & Aggregate: mean over all per-point scores \\
\bottomrule
\end{tabular}
\end{center}

% =============================================================================
\section{Label Convention}
% =============================================================================

\begin{itemize}[leftmargin=2em]
  \item Integer labels $\geq 0$ denote cluster membership.
  \item The label \texttt{-1} denotes a noise or outlier point (DBSCAN
        convention).
  \item Multiple noise points within a single call all share label \texttt{-1}
        but are treated as \emph{distinct singletons} internally when computing
        cluster scores (each receives a unique temporary negative label).
\end{itemize}

% =============================================================================
\section{Experimental Results}
% =============================================================================

This section compares the DISCO scores obtained from the R implementation
(\texttt{R-Disco}) and the Python implementation (\texttt{Python-Disco}) on two
benchmark datasets: \emph{Concentric Circles} and \emph{Moons}. The observed
differences are extremely small and are attributable to floating-point
precision at the level of machine epsilon ($\approx 2.2 \times 10^{-16}$).

\subsection{Concentric Circles Dataset}

\begin{center}
\begin{tabular}{p{4cm} p{4.4cm} p{4.4cm} p{3cm}}
\toprule
\textbf{Method} & \textbf{R-Disco} & \textbf{Python-Disco} & \textbf{Absolute Difference} \\
\midrule
DISCO --- DBSCAN &
0.69009218128208216214 &
0.69009218128208293930 &
{\color{softorange}\textbf{$7.77 \times 10^{-16}$}} \\
DISCO --- KMeans &
0.02700919079440020423 &
0.02700919079439973586 &
{\color{softorange}\textbf{$4.68 \times 10^{-16}$}} \\
\bottomrule
\end{tabular}
\end{center}

\paragraph{Interpretation.}
For the concentric circles dataset, both implementations produce practically
identical results. As expected, \textbf{DBSCAN} obtains a much higher DISCO
score than \textbf{KMeans}, since DBSCAN can recover non-convex circular
cluster structure while KMeans is centroid-based and not well suited for this
geometry.

\subsection{Moons Dataset}

\begin{center}
\begin{tabular}{p{4cm} p{4.4cm} p{4.4cm} p{3cm}}
\toprule
\textbf{Method} & \textbf{R-Disco} & \textbf{Python-Disco} & \textbf{Absolute Difference} \\
\midrule
DISCO --- DBSCAN &
0.70122811114499916663 &
0.70122811114499850049 &
{\color{softorange}\textbf{$6.66 \times 10^{-16}$}} \\
DISCO --- KMeans &
0.22303566235762423142 &
0.22303566235762423142 &
{\color{goodgreen}\textbf{0}} \\
\bottomrule
\end{tabular}
\end{center}

\paragraph{Interpretation.}
For the moons dataset, the R and Python implementations again agree almost
perfectly. DBSCAN achieves the best DISCO score because it correctly identifies
the curved, density-connected moon-shaped clusters. KMeans gives a noticeably
lower score because it tends to split the moons according to centroid proximity
rather than density-connected shape.

\subsection{Summary of Agreement}

\begin{itemize}[leftmargin=2em]
  \item The \textbf{largest discrepancy} observed across all experiments is on
        the order of $10^{-16}$ --- within machine epsilon.
  \item These differences are \textbf{numerically negligible} and expected for
        any two independent IEEE 754 floating-point implementations.
  \item The results confirm that the \textbf{R implementation reproduces the
        Python implementation faithfully}.
  \item In both datasets, \textbf{DBSCAN outperforms KMeans}, which is
        consistent with the density-based design of DISCO.
\end{itemize}

\subsection{Digit-level Comparison}

The diverging digits are highlighted to make the scale of difference visible.
All agreement up to the highlighted position is exact.

\vspace{0.8em}

\noindent\textbf{Concentric Circles --- DBSCAN}
\begin{quote}
\texttt{R\phantom{ython}:\ 0.690092181282082{\color{diffred}16214}}\\[0.3em]
\texttt{Python: 0.690092181282082{\color{difforange}93930}}
\end{quote}

\noindent\textbf{Concentric Circles --- KMeans}
\begin{quote}
\texttt{R\phantom{ython}:\ 0.027009190794400{\color{diffred}20423}}\\[0.3em]
\texttt{Python: 0.027009190794399{\color{difforange}73586}}
\end{quote}

\noindent\textbf{Moons --- DBSCAN}
\begin{quote}
\texttt{R\phantom{ython}:\ 0.70122811114499{\color{diffred}916663}}\\[0.3em]
\texttt{Python: 0.70122811114499{\color{difforange}850049}}
\end{quote}

\noindent\textbf{Moons --- KMeans}
\begin{quote}
\texttt{R\phantom{ython}:\ 0.22303566235762423142}\\[0.3em]
\texttt{Python: 0.22303566235762423142\quad{\color{goodgreen}(exact match)}}
\end{quote}

\vspace{0.8em}

\begin{center}
\begin{tabular}{p{6cm} p{7cm}}
\toprule
\textbf{Difference Magnitude} & \textbf{Interpretation} \\
\midrule
{\color{goodgreen}\textbf{0}} & Exact numerical agreement \\
{\color{softorange}\textbf{$< 10^{-15}$}} & Floating-point rounding; practically identical \\
{\color{softred}\textbf{$\geq 10^{-12}$}} & Potential implementation discrepancy worth investigating \\
\bottomrule
\end{tabular}
\end{center}

% =============================================================================
\end{document}