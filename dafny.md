# A verified vignette in Dafny
In this we will implement and verify solution of two sum problem. Two sum problem asks for a pair of indices in sorted sequence such that elements at those indices add up to given sum. It is given that such indices exists. Linear time implementation uses classic [two pointers technique](https://usaco.guide/silver/2P).

We will be using dafny for implementation and verification. Below is translation of [solution](https://rosettacode.org/wiki/Two_sum) in dafny.

```
method find_indices (s: seq<int>, sm: int) 
 returns (i: int, j: int)
{
  i := 0;
  j := |s| - 1;
  while i < j
  {
    if (s[i] + s[j] < sm){
      i := i + 1;
    }
    else if (s[i] + s[j] > sm){
      j := j - 1;
    }
    else{
      return i, j;
    }
  }
}
```

If you run above code snippet [online](https://www.rise4fun.com/Dafny), you will notice verification errors. It happens because dafny can't verify that sequence access is within its bounds. Let's fix this by providing loop invariant - predicate which is true when loop starts and after every iteration of loop including last run.

```
method find_indices (s: seq<int>, sm: int) 
 returns (i: int, j: int)
{
  i := 0;
  j := |s| - 1;
  while i < j
	 invariant 0 <= i <= j < |s|
  {
    if (s[i] + s[j] < sm){
      i := i + 1;
    }
    else if (s[i] + s[j] > sm){
      j := j - 1;
    }
    else{
      return i, j;
    }
  }
}
```

Notice invariant says  `i <= j`  where as loop condition is `i < j` . This is due to loop invariant  should be true after last run of loop. After last run of loop `i` is equal to `j`. If you run above code snippet it will give verification error still as loop invariant is not maintained at start if sequence is empty. To fix it temporarily you can add `requires |s| >= 1` .

```
method find_indices (s: seq<int>, sm: int) 
 returns (i: int, j: int)
 requires |s| >= 1
```

`requires` adds precondition to method. `find_indices` can now assume that sequence contains at least one element. You can't call `find_indices` with empty sequence now as it violates its contracts.

This brings us to preconditions of two sum problem 

 * Sequence is sorted
 * There exists indices pair, whose elements add upto sum

We need predicate which classifies whether sequence is sorted or not.

```
predicate sorted (s: seq<int>)
{
  if |s| <= 1 then true else s[0] <= s[1] && sorted(s[1..])
} 
```

After defining sorted predicate, let's add all preconditions to `find_indices` method.

```
method find_indices (s: seq<int>, sm: int) 
 returns (i: int, j: int)
 requires sorted(s)
 requires exists m, n :: 0 <= m < n < |s| && s[m] + s[n] == sm
{
  i := 0;
  j := |s| - 1;
  while i < j
	 invariant 0 <= i <= j < |s|
  {
    if (s[i] + s[j] < sm){
      i := i + 1;
    }
    else if (s[i] + s[j] > sm){
      j := j - 1;
    }
    else{
      return i, j;
    }
  }
}
```

This is runnable and verifiable. But it does n't say anything about returned indices. We need contract attached to `find_indices`  that it returns right indices. Using `ensures`, we can do exactly that. It adds postcondition to method - predicates which must hold when method returns. Let's add what we intended to return. 

```
method find_indices (s: seq<int>, sm: int) 
 returns (i: int, j: int)
 requires sorted(s)
 requires exists m, n :: 0 <= m < n < |s| && s[m] + s[n] == sm
 ensures 0 <= i < j < |s| && s[i] + s[j] == sm
```

If you verify after adding postcondition, it will throw verification error. Dafny can't prove postcondition by itself, we need to guide dafny to verify that.

Before verifying postcondition, we need to take little detour to prove small lemma which will be required later. 

Lemma - Given sorted sequence `s` and two indices `m`, `n` such that `m <= n` then `s[m] <= s[n]`.

Translation of lemma in dafny and its verification is given in code snippet below.  Proof uses induction on `m`, `n`, with difference between `n` and `m` decreasing when relying on inductive argument. If `m == n` then `s[m] <= s[n]` else using induction `m + 1 <= n` implies `s[m+1] <= s[n]`. We additionally require `s[m] <= s[m+1]` which together with `s[m+1] <= s[n]` will prove `s[m] <= s[n]`.

We need to fetch information `s[m] <= s[m+1]` from sorted predicate. `sorted(s[m..])` implies `s[m] <= s[m+1]` by definition. Stating `sorted(s[m..])` holds requires iterative argument which is done by `while` loop.

* `sorted(s)` implies (by definition)
* `sorted(s[1..])` implies (by definition)
* `sorted(s[2..])`  implies (by definition)
* `....`  
* `sorted(s[m..])`

```
lemma {:induction m, n} sorted_elem_lemma(s: seq<int>, m: int, n: int)
 decreases n - m
 requires sorted(s)
 requires 0 <= m <= n < |s|
 ensures s[m] <= s[n]
{
  if(m == n) {}
  else {
    sorted_elem_lemma(s, m+1, n);
    var i := 0;
    while i < m
     invariant i <= m < |s|
     invariant sorted(s[i..])
    {
      if( i == 0 ) {}
      else {
        assert sorted(s[(i+1)..]);
      }
      i := i + 1;
    }
  }
}
```

With above lemma at hand, we can now prove postcondition holds. Addition invariants which are maintained by loop are

* pair of indices which add upto sum lies between loop variables
* for every pair of indices in which one of index lies outside loop variables does n't add upto sum


```
method find_indices (s: seq<int>, sm: int) returns (i: int, j: int)
  requires sorted(s)
  requires exists m, n :: 0 <= m < n < |s| && s[m] + s[n] == sm
  ensures 0 <= i < j < |s| && s[i] + s[j] == sm
{
  i := 0;
  j := |s| - 1;

  while i < j
    invariant 0 <= i <= j < |s|
    invariant exists m, n :: i <= m < n <= j && s[m] + s[n] == sm
    invariant forall m, n :: 0 <= m < i && m < n < |s| ==> s[m] + s[n] != sm
    invariant forall m, n :: j < n < |s| && 0 <= m < n ==> s[m] + s[n] != sm
  {
    if (s[i] + s[j] < sm){
      forall k | i < k < |s| ensures s[i] + s[k] != sm {
        if k <= j {
          sorted_elem_lemma(s, k, j);
          assert s[k] <= s[j];
          assert s[i] + s[k] <= s[i] + s[j];
        }
      }
      i := i + 1;
    }
    else if (s[i] + s[j] > sm){
      forall k | 0 <= k < j ensures s[k] + s[j] != sm {
        if i <= k {
          sorted_elem_lemma(s, i, k);
          assert s[i] <= s[k];
          assert s[i] + s[j] <= s[k] + s[j];
        }
      }
      j := j - 1;
    }
    else{
      return i, j;
    }
  }
}

```

Complete source code can be found [here](https://gist.github.com/rdivyanshu/052fc8b2c5bb62fc33c3065d42b2ad81).
