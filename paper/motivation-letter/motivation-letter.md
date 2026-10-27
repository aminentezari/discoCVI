---
output: pdf_document
fontsize: 12pt
---

\thispagestyle{empty}
\today

Editor
The R Journal
\bigskip

Dear Editor,
\bigskip

Please consider my article titled "Fast and Memory-Light Evaluation of
Density-Based Clusterings with the DISCO Index in R" for publication in the
R Journal.

DISCO is a recent internal cluster validity index for density-based
clustering (Beer et al., ICLR 2026) and the first to evaluate the quality of
noise labels. Its definition relies on distances between all pairs of
points, so direct implementations, including the first CRAN release of my
package discoCVI, need several n x n matrices and are limited to a few
thousand points.

The article shows that every quantity DISCO requires can be obtained from
the single-linkage merge tree of the mutual-reachability minimum spanning
tree in one pass, which gives an exact algorithm with memory linear in the
number of points. It describes the implementation in discoCVI 0.2.0, its
test suite against the previous version, a correction of the score of
singleton clusters to match the published definition, and a benchmark of
time, memory and energy consumption. I believe the article is of interest
to R Journal readers working on clustering and model selection, and to those
concerned with the computational and environmental cost of statistical
software.

The manuscript has not been published or submitted elsewhere.

\bigskip
\bigskip

Regards,

Amin Entezari
Università di Milano-Bicocca, Milan, Italy
amin_entezari@outlook.com

\bigskip
