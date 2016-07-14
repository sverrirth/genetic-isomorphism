-module(framework).

-export([main/0]).

-define(NODES_LARGER, 100).
-define(DEGREE_LARGER, 10).
-define(NODES_SMALLER, 10).
-define(DEGREE_SMALLER, 5).
-define(POPULATION, 1000).
-define(BEST_OFFSPRING, 20).
-define(CHILD_TRIES, 10).
-define(GENERATIONS, 100).

create_graph(Nodes, Degree) ->
	{G, E} = add_nodes(digraph:new(), Nodes, []),
	add_edges(G, E, Degree, Nodes).
	
add_nodes(G, 0, E) ->
	{G, E};
add_nodes(G, N, E) ->
	V = digraph:add_vertex(G, N),
	add_nodes(G, N-1, [V | E]).
	
add_edges(G, E, _, 0) ->
	{G, E};
add_edges(G, E, D, N) ->
	G = add_edges_node(G, lists:delete(N, E), D, N),
	add_edges(G, E, D, N-1).

add_edges_node(G, _, 0, _) ->
	G;
add_edges_node(G, E, D, N) ->
	Index = random:uniform(length(E)),
	_ = digraph:add_edge(G, N, Index),
	add_edges_node(G, lists:delete(Index, E), D-1, N).
	
calc_fitness([], _, _, N) ->
	report_back([], N);
calc_fitness([P | Population], Big, Small, N) ->
	Me = self(),
	spawn(fun() -> calc_individual(Me, P, Big, Small) end),
	calc_fitness(Population, Big, Small, N+1).
	
calc_individual(Parent, P, Big, Small) ->
	F = fitness(P, Big, Small),
	case F of
		0 ->
			io:write({solution, P}),
			init:stop();
		_ ->
			Parent ! {not_solution, P, F}
	end.
	
report_back(Population, N) ->
	receive
		{not_solution, P, F} ->
			case N of
				1 ->
					flush(),
					[{P, F} | Population];
				_ ->
					report_back([{P, F} | Population], N-1)
			end
	end.

fitness(L, Big, Small) ->
	fitness(length(L), L, Big, Small, 0).	

fitness(0, _, _, _, Sum) ->
	Sum;
fitness(N, L, Big, Small, Sum) ->
	X = lists:map(fun(X) -> index_of(X, L) end, intersection(digraph:out_neighbours(Big, lists:nth(N, L)), L)),
	FromSum = fit_individual(X, digraph:out_neighbours(Small, N), 0),
	ToSum = fit_individual(digraph:out_neighbours(Small, N), X, 0),
	fitness(N-1, L, Big, Small, FromSum + ToSum + Sum).

fit_individual([], _, Sum) ->
	Sum;
fit_individual([F | Fs], SmallNeighbors, Sum) ->
	case lists:member(F, SmallNeighbors) of
		true ->
			fit_individual(Fs, SmallNeighbors, Sum);
		false ->
			fit_individual(Fs, SmallNeighbors, Sum+1)
	end.
	
make_chromosomes() ->
	make_chromosomes(?POPULATION, []).
	
make_chromosomes(0, All) ->
	All;
make_chromosomes(N, All) ->
	make_chromosomes(N-1, [make_chromo([], ?NODES_SMALLER, lists:seq(1, ?NODES_LARGER)) | All]).
	
make_chromo(Chromo, 0, _) ->
	Chromo;
make_chromo(Chromo, N, B) ->
	Random = random:uniform(length(B)),
	make_chromo([lists:nth(Random, B) | Chromo], N-1, lists:delete(Random, B)).
	
find_children(Population, Big, Small) ->
	find_children(Population, Big, Small, ?BEST_OFFSPRING, []).
	
find_children(_, _, _, 0, Children) ->
	Children;
find_children(Population, Big, Small, N, Children) ->
	find_children(Population, Big, Small, N-1, [crossover(find_parent(Population), find_parent(Population), Big, Small) | Children]).
	
find_parent(All) ->
	[{_, BestFitness} | _] = All,
	RandomIndex = random:uniform(length(All)),
	{Candidate, Fitness} = lists:nth(RandomIndex, All),
	Random = random:uniform(),
	case (BestFitness/Fitness)>Random of
		true ->
			Candidate;
		false ->
			find_parent(All)
	end.
	
crossover(L1, L2, Big, Small) ->
	Children = make_children(?BEST_OFFSPRING, L1 ++ L2, []),
	Fitnesses = calc_fitness(Children, Big, Small, 0),
	find_min(Fitnesses).
	
make_children(0, _, All) ->
	All;
make_children(N, L, All) ->
	make_children(N-1, L, [select(L, ?NODES_SMALLER, []) | All]).
	
select(_, 0, Nodes) ->
	shuffle(Nodes);
select(All, N, Nodes) ->
	Index = random:uniform(length(All)),
	Element = lists:nth(Index, All),
	select(lists:delete(Element, All), N-1, [Element | Nodes]).
	
find_min([{First, Fitness} | Rest]) ->
	find_min(Rest, First, Fitness).
find_min([], Child, Smallest) ->
	{Child, Smallest};
find_min([{Current, Fitness} | Rest], Child, Smallest) ->
	case Fitness<Smallest of
		true ->
			find_min(Rest, Current, Fitness);
		false ->
			find_min(Rest, Child, Smallest)
	end.
	
replace_worst(Population, Children) ->
	lists:sublist(Population, ?POPULATION - ?BEST_OFFSPRING) ++ Children.
	
shuffle(L) ->
	[X||{_,X} <- lists:sort([ {random:uniform(), N} || N <- L])].  %http://stackoverflow.com/a/8820501
	
index_of(Item, List) -> index_of(Item, List, 1).
index_of(_, [], _)  -> not_found;
index_of(Item, [Item|_], Index) -> Index;
index_of(Item, [_|Tl], Index) -> index_of(Item, Tl, Index+1).
	
intersection(L1,L2) -> lists:filter(fun(X) -> lists:member(X,L1) end, L2).

flush() ->  %clear out old messages from the inbox
  receive
    _ -> flush()
  after 0 ->
    ok
  end.

generation(_, _, Pop, 0) ->
	io:fwrite("The best solution found is\n"),
	find_min(Pop);
generation(Big, Small, Pop, N) ->
	Sorted = lists:keysort(2, Pop),
	Children = find_children(Sorted, Big, Small),
	NextGeneration = replace_worst(Sorted, Children),
	generation(Big, Small, NextGeneration, N-1).
	
main() ->
	{Big, _} = create_graph(?NODES_LARGER, ?DEGREE_LARGER),
	{Small, _} = create_graph(?NODES_SMALLER, ?DEGREE_SMALLER),
	Population = make_chromosomes(),
	Fitnesses = calc_fitness(Population, Big, Small, 0),
	generation(Big, Small, Fitnesses, ?GENERATIONS).
	