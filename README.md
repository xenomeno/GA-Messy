# Messy and Fast Messy Genetic Algorithm

This is Lua implementation of the Messy and Fast Messy Genetic Algorithms as described in the papers:

  - Messy Genetic Algorithms: Motivation, Analysis, and First Results by David E. Goldberg, Bradley Korb and Kalyanmoy Deb
  - Messy Genetic Algorithms Revisited: Studies in Mixed Size and Scale by David E. Goldberg, Kalyanmoy Deb and Bradley Korb
  - Rapid, Accurate Optimization of Difficult Problems Using Fast Messy Genetic Algorithms by David E. Goldberg, Kalyanmoy Deb, Hillol Kargupta and Georges Harik
  
Bitmap file saving implementation is in pure Lua and is very slow but is just used to draw graphs for comparisons.

First are presented the reproduction of the graphs from the original Messy GA from the excelent first paper. Following it becomes very easy for algorithm implementation and it starts with the Simple GA and presenting the difference between three different orderings in chromosome representation(Tight, Loose and Random):

![](mGA/mGA_SGA_Max.bmp?raw=true "Simple GA and Orderings")
