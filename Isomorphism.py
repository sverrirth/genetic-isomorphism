from multiprocessing import Pool

import networkx as nx
import random
import sys
import time

big_nodes = 100
small_nodes = 10
big_density = 10
small_density = 5
generation_no = 100
population_size = 100
children_no = 20
processor_no = 8
child_tries = 10

big_list = list(xrange(big_nodes))
small_list = list(xrange(small_nodes))

big = None
small = None

def fitness(chromosome, big, small):

    comparison = nx.DiGraph()

    nodes_on_small = nx.nodes(small)

    for i in nodes_on_small:
        comparison.add_node(i)

    for i in xrange(len(chromosome)):
        chromo = chromosome[i]
        first = i+1
        neighbors = nx.neighbors(big, chromo)
        both = list(set(neighbors).intersection(chromosome))
        for x in both:
            second = chromosome.index(x) + 1
            comparison.add_edge(first, second)

    out_sum = 0
    in_sum = 0

    for e in comparison.edges():
        if not e in small.edges():
            out_sum += 1

    for e in small.edges():
        if not e in comparison.edges():
            in_sum += 1

    return out_sum+in_sum

def make_graph(list, density):
    g = nx.DiGraph()
    for i in list:
        g.add_node(i)
    for node in nx.nodes(g):
        while g.out_degree(node)<density:
            rand = random.choice(nx.nodes(g))
            if rand != node:
                g.add_edge(node, rand)
    return g

def make_children(pop, big_graph, small_graph, the_pool):
    ret = []
    for i in xrange(children_no):
        ret.append(make_child(pop, big_graph, small_graph, the_pool))
    return ret

def make_child(pop, big_graph, small_graph, the_pool):
    best_fitness = pop[0][1]
    tries = []
    for _ in xrange(child_tries):
        first = find_parent(best_fitness, pop)
        second = find_parent(best_fitness, pop)
        tries.append([crossover(first, second), big_graph, small_graph])
    children_fitness = the_pool.map(apply_fitness, tries)
    children_fitness.sort(key=lambda x: x[1])
    return children_fitness[0]

def crossover(first, second):
    both = first[0] + second[0]
    result = random.sample(both, len(first[0]))
    return result

def find_parent(best_fitness, pop):
    rand = random.choice(xrange(len(pop)))
    unirandom = random.uniform(0.0,1.0)
    while float(best_fitness)/pop[rand][1]<unirandom :
        rand = random.choice(xrange(len(pop)))
        unirandom = random.uniform(0.0,1.0)
    return pop[rand]

def apply_fitness(x):
    chromosome = x[0]
    big_graph = x[1]
    small_graph = x[2]
    return [chromosome, fitness(chromosome, big_graph, small_graph)]

if __name__ == '__main__':

    start_time = time.clock()

    big = make_graph(big_list, big_density)
    small = make_graph(small_list, small_density)

    population = []

    for _ in xrange(population_size):

        population.append([[big_list[i] for i in random.sample(xrange(len(big_list)), small_nodes)], big, small])

    pool = Pool(processes=processor_no)

    population_applied = pool.map(apply_fitness, population)

    population_applied.sort(key=lambda x: x[1])

    for _ in xrange(generation_no):

        children = make_children(population_applied, big, small, pool)
        population_applied = population_applied[:(population_size-children_no)] + children
        population_applied.sort(key=lambda x: x[1])
        if population_applied[0][1] == 0:
            print population_applied[0]
            print (time.clock()-start_time)
            sys.exit(0)

    print population_applied[0]
    print (time.clock()-start_time)