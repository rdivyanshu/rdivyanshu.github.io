---   
title: Verifying using temporal logic of action in Dafny
date-meta: 2024-01-25
description-meta: How to write and proof temporal logic statements in Dafny ?
---

In [previous blog](../../2023/08/stuttering-steps-in-tla.html) we looked into why TLA+ specification enforces SI (stuttering insensitivity) and 
how verifying liveness assertion required us to add fairness condition in spec. In this blog
we will model timer displaying minute in Dafny using temporal logic of action. And then
we will prove that specification, with fairness condition included, implies that timer will eventually
reach 0 (In previous blog we model checked this property).

First order of business is encode state of our system, specify what it is correct initial state
and how system moves from one state to another. We need to be mindful that our action satisfies 
stuttering insensitivity requirement of temporal logic of action. Formally step `st` is enabled in state 
`s` if there exists state `e` such that `st(s, e)` is true. There is easier way to say so for DecreaseMin 
step that is min is greater than 0.

~~~{.dafny}
datatype State = State(min: int)

predicate Init(s: State){
  s.min == 5
}

predicate EnabledDecreaseMin(s: State){
  s.min > 0
}

predicate DecreaseMin(s: State, t: State){
  EnabledDecreaseMin(s) && s.min - 1 == t.min
}

predicate Stutter(s: State, t: State){
  s.min == t.min
}

predicate Next(s: State, t: State){
  DecreaseMin(s, t) || Stutter(s, t)
}
~~~

TLA+ avoids explicit mention of index of state in behavior. In Dafny we will be using infinite map `imap` 
to model behavior where value at key `n` is `nth` state. That is why we have additional requirement in spec that 
every natural number exists in map. Next we want DecreaseMin step to be weakly fair. I am using definition from 
Chapter 8 of Specifying Systems where it is defined to be `[]([](Enabled <A>_v) => <><A>_v)`. Step `st` is 
weakly fair if `st` is enabled forever then eventually `st` will happen. There are alternate ways to say step is 
weakly fair, equivalent to this definition. Some triggers are mentioned in code below which helps SMT solvers to 
use quantifiers in guided manner but can be ignored for this discussion.

~~~{.dafny}
function Increase(i: nat): nat {
  i+1
}

ghost predicate WeakFairness(t: imap<nat, State>)
  requires forall i : nat :: i in t
{
   forall i: nat {:trigger EnabledDecreaseMin(t[i])} :: (
      (forall j: nat :: j >= i ==> EnabledDecreaseMin(t[j]))
      ==>
      (exists k: nat :: k >= i && DecreaseMin(t[k], t[Increase(k)]))
   )
}

function Identity(n: nat) : nat {
  n
}

ghost predicate Spec(t: imap<nat, State>){
   (forall i : nat :: i in t)
 && Init(t[0])
 && (forall i : nat {:trigger Identity(i)}:: Next(t[i], t[i+1]))
 && WeakFairness(t)
}
~~~

We need two safety properties to prove liveness property. First is `min` is always greater than
or equal to 0. And second is `min` is non increasing in behavior. I have omitted proof but it 
can be seen [here](https://gist.github.com/rdivyanshu/f2b0a03c6ceeb7659ec6bf9db91e3c86).

~~~{.dafny}
lemma Safety(t: imap<nat, State>, k: nat)
  requires Spec(t)
  ensures t[k].min >= 0


lemma SafetyDecreasing(t: imap<nat, State>, m: nat, n: nat)
  requires Spec(t)
  requires m <= n
  ensures t[m].min >= t[n].min
~~~

To prove that timer will eventually reach 0 we start with initial state and try to convince Dafny that we can always 
find state `m` (I am using index of state as synonyms for that state) in which `min` is 0. There are two cases to consider 
a) when antecedent of weak fairness is true and b) when it is false. In second case antecedent being false means there exists 
state `k` at which `min` is less than or equal to 0 which together with safety condition proves that `min` is exactly 0. 
In first case applying antecedent to weakly fair property gives us state `k` at which next transition will decreases `min`. 
Note that it just says that `min` will decrease between state `k` and `k+1`. It is required that current state `r` has
`min` value greater than or equal to `min` of state `k` to prove that `min` actually decreases during our search. This is done 
using safety property `SafetyDecreasing`. Since `min` is finite positive number applying this argument again and again we 
will reach state `m` where `min` is 0.

~~~{.dafny}
lemma ExistsHelperLemma(t: imap<nat, State>, m: nat)
  requires forall i : nat :: i in t
  requires !(forall j : nat :: j >= m ==> EnabledDecreaseMin(t[j]))
  ensures exists k : nat :: k >= m && !EnabledDecreaseMin(t[k])
{}

lemma Eventually(t: imap<nat, State>)
  requires Spec(t)
  ensures exists m : nat :: t[m].min == 0
{
   var r : nat := 0;
   while t[r].min > 0
    invariant t[r].min >= 0
    decreases t[r].min
   {
     if(forall j : nat :: j >= r ==> EnabledDecreaseMin(t[j])) {
        assert exists k: nat :: k >= r && DecreaseMin(t[k], t[Increase(k)]) by {
          assert r == Identity(r);
          assert EnabledDecreaseMin(t[r]);
          assert
            (forall j : nat :: j >= r ==> EnabledDecreaseMin(t[j])) ==>
            (exists k: nat :: k >= r && DecreaseMin(t[k], t[Increase(k)]));
        }
        var k :| k >= r && DecreaseMin(t[k], t[Increase(k)]);
        assert Increase(k) == k + 1;
        SafetyDecreasing(t, r, k);
        assert t[r].min >= t[k].min;
        assert t[k+1].min == t[k].min - 1;
        assert t[r].min >= t[k].min > t[k+1].min;
        r := k + 1;
        if t[r].min == 0 { return; }
     }
     else {
        assert !(forall j : nat :: j >= r ==> EnabledDecreaseMin(t[j]));
        ExistsHelperLemma(t, r);
        var k :| k >= r && !EnabledDecreaseMin(t[k]);
        assert t[k].min <= 0;
        Safety(t, k);
        return;
     }
   }
}
~~~
There is alternate way to think about this proof. When does timer will never reach state where `min` is 0 assuming 
safety part of spec (`Init` and `Next`) ? It is when timer stops working when `min` is displaying some number greater 
than 0 - behavior stutters infinitely afterwards. Does our spec include such behavior? In this behavior weakly fair condition
allows us to find sequence of states in which `min` is decreasing to 0. But this is contradiction.
Hence such behavior is not satisfied by our Spec. 

This is rather silly example to show temporal logic argument - there is no two or more processes/servers competing for fair 
execution. But I hope this small example which is written in programming language like syntax shows how such argument 
works. 
