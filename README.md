# Messy and Fast Messy Genetic Algorithm

This is Lua implementation of the Messy and Fast Messy Genetic Algorithms as described in the papers:

  - Messy Genetic Algorithms: Motivation, Analysis, and First Results by David E. Goldberg, Bradley Korb and Kalyanmoy Deb
  - Messy Genetic Algorithms Revisited: Studies in Mixed Size and Scale by David E. Goldberg, Kalyanmoy Deb and Bradley Korb
  - Rapid, Accurate Optimization of Difficult Problems Using Fast Messy Genetic Algorithms by David E. Goldberg, Kalyanmoy Deb, Hillol Kargupta and Georges Harik
  
Bitmap file saving implementation is in pure Lua and is very slow but is just used to draw graphs for comparisons.

# Messy GA

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

# Fast Messy GA

Unfortunately things are not so easy with the fast version of the messy GA where the primordial phase is replaced by Probabilisticaly Complete Initialization combing with filtering and length reduction of the initial messy chromosomes. As a start it was not clear to me how they calculate the size of the population and more precisely the term:

![](fmGA/PopSize.jpg?raw=true "Population Size accounting for noise")

In our case m=10, k=3 and using the table below for the fitness of the order-3 deceptive function the square of beta is variance of that function divided by the square of the signal(difference between the best and second best), i.e. 155 / 2 = 38.75.

![](fmGA/Order3.jpg?raw=true "Fitness for the Order-3 Deceptive function")

The first problem is the parameter c(alpha) which is a bit more tricky to figure out. Alpha is nowhere specified in the paper as a concrete value but they say the initial population size they found using the full equation is 3,331. This leaves 0,43 for c(alpha). Initially I thought that using that area as the right tail of a cumulative probability for making error during selection less than alpha means that inverse normal distribution should be used to find the Z-score having that alpha. Then using that Z-score in the normal distribution equation should give the height(the value of the ND) and it just needs to be squared and substituted in the equation. However the square of height being 0,43 means the height itself should be sqrt(0,43)=0,66 which makes no sense as the maximum height in the normal distribution should be around 0,4. After googling for a while it turns out to me that by square of the ordinate they may mean just the square of the Z-score. Well having Z-score 0,66 and going backwards it appears the probability of choosing inferior schemata must be about 25% which means I might be wrong for that too. Anyway for the test of 10 order-3 deceptive functions the population size used for the figures below will be 3,331 as is in the paper.

Here is the first reproduced figure of the population size Ng plotted for k against initial string length:

![](fmGA/N_G.bmp?raw=true "Population Size Ng")

Next is the the graph for the square of the Z-score(square of the ordinate) against the input parameter alpha. Note that if this is drawn in the log scale for alpha it will be almost a straight line as is in the paper. This means my assumption about what c(alpha) is may be not that wrong:

![](fmGA/C_ALPHA.bmp?raw=true "Square of the ordinate as a function of alpha")


