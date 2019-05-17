# Messy and Fast Messy Genetic Algorithm

This is Lua implementation of the Messy and Fast Messy Genetic Algorithms as described in the papers:

  - Messy Genetic Algorithms: Motivation, Analysis, and First Results by David E. Goldberg, Bradley Korb and Kalyanmoy Deb
  - Messy Genetic Algorithms Revisited: Studies in Mixed Size and Scale by David E. Goldberg, Kalyanmoy Deb and Bradley Korb
  - Rapid, Accurate Optimization of Difficult Problems Using Fast Messy Genetic Algorithms by David E. Goldberg, Kalyanmoy Deb, Hillol Kargupta and Georges Harik
  
Bitmap file saving implementation is in pure Lua and is very slow but is just used to draw graphs for comparisons.

First are presented the reproduction of the graphs from the original Messy GA from the excelent first paper. Following it becomes very easy for algorithm implementation. It starts with the Simple GA and presenting the difference between three orderings in chromosome representation(Tight, Loose and Random) as maximum number of Building Blocks '111' of 10 order-3 deceptive functions concatenated together(describerd in the paper):

![](mGA/mGA_SGA_Max.bmp?raw=true "Simple GA and Orderings - Max BBs")

Here is also the average number of BBs during the same simulation. Both results are averaged over 10 runs as the initial random seeds are kept the same for the three different orderings which leads for the initial population to be exactly the same:

![](mGA/mGA_SGA_Avg.bmp?raw=true "Simple GA and Orderings - Average BBs")

Next are the results for the Messy GA again averaged over 10 runs. Mutation probability is kept to 0, Splice probability is 1.0 and Cut probability is 1 / (2 * CHROMOSOME_LENGTH) where in our case the chromosome case is 30 = 10 * 3(SUB_FUNCTION_ORDER * SUB_FUNCTIONS). The fitness chart clearly shows that the generation at which the best solution is found is earlier than the Simple GA and is as soon as the splice operator makes the messy chromosome long enough to represent the solution. Comparison is made between the Partial Specification,Partial Evaliuation and Competitive Template methods used for calculating the fitness of messy chromosome:

![](mGA/mGA_MGA_FITNESS.bmp?raw=true "Messy GA Fitness")

Similar comparison charts are present for the minimum, average and maximum proportion of the BBs for both methods too:

![](mGA/mGA_MGA_BBLOCKS.bmp?raw=true "Messy GA BBs")

Finally chart for how the length of the messy chromosome grows outlines that competitive template method create much shorter chromosomes:

![](mGA/mGA_MGA_LENGTHS.bmp?raw=true "Messy GA BBs")
