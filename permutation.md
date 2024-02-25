# Another verified program in Dafny

Permutations of multiset can be generated in lexicographical order. Wikipedia has description
of how such [algorithm](https://en.wikipedia.org/wiki/Permutation#Generation_in_lexicographic_order) works. 
Let's implement `next_permutation` in Dafny which given array  as input returns next permutation. 
Fun and challenging part of implementing in Dafny is verification.

First we need to identify whether two arrays (sequences) are permutation of each other.

```
predicate permutation(m: seq<nat>, n: seq<nat>)
{
  && |m| == |n| 
  && multiset(m[..]) == multiset(n[..])
}
```

We also need to figure out lexicographical order of sequences - `(greater m n)` is 
true when n is lexicographically greater than m.

```
predicate greater(m: seq<nat>, n: seq<nat>)
  requires |m| == |n|
{
  exists j :: 0 <= j < |m| 
     && (forall i :: 0 <= i < j ==> m[i] == n[i]) 
     && m[j] < n[j]
}
```

With setup being done, let's write interface of `next_permutation`. If input is largest
permutation then we can't find next permutation. It is captured by first postcondition
- if `ok` is false then there is no next permutation which happens when array is largest in
lexicographical order (i.e. `arr` is decreasing sequence). Next postcondition says that array 
we return is indeed permutation of input and it is greater than input. Last postcondition 
enforces that if there is another sequence `m` such that `m` is permutation of `arr` and greater 
than `arr` then either it is equal to `res` or `m` is greater than `res`. This inforces that `res` 
is next permutation.

```
method next_permutation(arr: array<nat>)
  returns (ok: bool, res: array<nat>)
  ensures !ok ==> decreasing(arr[..])
  ensures ok ==> permutation(arr[..], res[..]) && greater(arr[..], res[..])
  ensures ok ==> forall m :: permutation(arr[..], m) && greater(arr[..], m) ==>
                  greater(res[..], m) || (res[..] == m)
```

Proving last postcondition will be hardest so let's ignore this for now. Code listed
below is implementation of algorithm on Wikipedia with few invariants thrown below
while loop. In the end of method we ask Dafny to prove postconditions for us
which it obliges. We needed one additional lemma `identity_permutation` and implementation
of `copy` and `reverse` methods with exhaustive postconditions. Implemenation of which can be
seen [here](https://gist.github.com/rdivyanshu/c7ced3c3ff2bfc9c3cc38b2cae6609f0) in final verified program.

```
method next_permutation(arr: array<nat>)
  returns (ok: bool, res: array<nat>)
  ensures !ok ==> decreasing(arr[..])
  ensures ok ==> permutation(arr[..], res[..]) && greater(arr[..], res[..])
{
  res := new nat[arr.Length];
  copy(arr, res);
  
  if arr.Length <= 0 {
    ok := false;
    return;
  }
  
  var i := arr.Length - 1;
  while i > 0 && arr[i-1] >= arr[i]
    invariant i >= 0
    invariant forall k :: i < k < arr.Length ==> arr[k-1] >= arr[k]
  {
    i := i-1;
  }

  if i <= 0 {
    ok := false;
    return;
  }

  var j := arr.Length - 1;

  while arr[j] <= arr[i-1]
    decreases j - i
    invariant j >= i
    invariant forall k :: j < k < arr.Length ==> arr[k] <= arr[i-1]
  {
     j := j - 1;
  }

  identity_permutation(arr[..], res[..]);

  res[i-1], res[j] := res[j], res[i-1];
  reverse(res, i, res.Length-1);
  assert permutation(arr[..], res[..]);
  assert greater(arr[..], res[..]);

  ok := true;
}
```

One of favourite saying from [Developing Verified Programs in Dafny](https://leino.science/papers/krml233.pdf) is 
- How strong or weak to make a specification is an engineering choice—a trade-off between assurance and the price to obtain 
that assurance. We want to prove third postcondition. So let's pay the price - providing argument with enough details 
that computer can accept it. Convincing will require lines of code as large as initial implementation, as Dafny can't figure 
out details like it did for first two postconditions.

Few observations that will help latter : 

- `arr[i..]` is decreasing sequence (invariant of first while loop).
- `arr[i-1]` is greater or equal to elements of sequence `arr[(j+1)..]` (invariant of second while loop).  
- `arr[i-1]` is less than elements of sequence `arr[i..(j+1)]`. This follows from first observation and loop condition of second while loop.
- `res[i..]` is increasing sequence. Initially `res` is copy of `arr` hence `res[i..]` is decreasing sequence. Even after swaping `res[i-1]` and `res[j]`,
   `res[i..]` is decreasing sequence. Finally reverse operation makes `res[i..]` an increasing sequence.

Adding assert statement makes Dafny prove last observation which it does without any help. Second statement in code snippet below
is [calculation](https://cseweb.ucsd.edu/~npolikarpova/publications/vstte13.pdf) proof to establish obvious fact.

```
  assert increasing(res[i..]);
  calc {
    multiset(arr[(i-1)..]);
    { assert arr[..] == arr[..(i-1)] + arr[(i-1)..]; }
    multiset(arr[..]) - multiset(arr[..(i-1)]);
    { assert arr[..(i-1)] == res[..(i-1)]; }
    multiset(res[..]) - multiset(res[..(i-1)]);
    { assert res[..] == res[..(i-1)] + res[(i-1)..]; }
    multiset(res[(i-1)..]);
  }
```

Complete proof of third postcodition is listed below. Proof uses case analysis on index used in `greater` predicate.
There are three cases to consider. If `k` is less than `i-1` then `arr[..k] == res[..k]` and `arr[k] == res[k]`.
It is easy to prove `greater(res, m)` from these facts. In fact Dafny is able to do it automatically. Case when `k` is greater than
`i-1` is impossible which we show by proving false. Observe that `m[k]` should be in `multiset(m[k..])` hence in `multiset(arr[k..])`.
Since `arr[k..]` is decreasing sequence `m[k]` should be less or equal to `arr[k]`, first element of sequence. Starting 
with assumption `arr[k]` is less than `m[k]` we proved that `m[k]` is less or equal to `arr[k]`, a contradiction.

```
forall m | permutation(arr[..], m) && greater(arr[..], m) ensures
    greater(res[..], m) || (res[..] == m)
  {
    if res[..] == m {}
    else {
      var k :| 0 <= k < arr.Length && 
           (forall l :: 0 <= l < k ==> arr[l] == m[l]) && arr[k] < m[k];
      calc {
        multiset(arr[k..]);
        { assert arr[..] == arr[..k] + arr[k..]; }
        multiset(arr[..]) - multiset(arr[..k]);
        { assert permutation(arr[..], m); identity_permutation(arr[..k], m[..k]); }
        multiset(m) - multiset(m[..k]);
        { assert m == m[..k] + m[k..]; }
        multiset(m[k..]);
      }
      if k < i - 1 {}
      else if k > i - 1 {
        assert m[k] in multiset(arr[k..]) by
          { assert multiset(arr[k..]) == multiset(m[k..]); }
        assert m[k] <= arr[k] by
          { assert decreasing(arr[k..]); decreasing_aux_lemma(m[k], arr[k..]); }
        assert false by
          { assert m[k] <= arr[k]; assert arr[k] < m[k]; }
      }
      else {
        if m[k] == res[k] {
          calc {
            multiset(m[(k+1)..]);
            { assert m[k..] == m[k..(k+1)] + m[(k+1)..]; }
            multiset(m[k..]) - multiset(m[k..(k+1)]);
            { assert m[k..(k+1)] == res[k..(k+1)]; }
            multiset(arr[k..]) - multiset(res[k..(k+1)]);
            multiset(res[k..]) - multiset(res[k..(k+1)]);
            { assert res[k..] == res[k..(k+1)] + res[(k+1)..]; }
            multiset(res[(k+1)..]);
          }
          assert greater(res[..], m) by {
            increasing_multiset_aux_lemma(res[(k+1)..], m[(k+1)..]);
          }
        }
        else if m[k] < res[k] {
          forall l | l in multiset(arr[k..]) && arr[k] < l 
            ensures res[k] <= l 
          {
            var idx :| k <= idx < arr.Length && arr[idx] == l;
            if idx == i - 1 {
              assert false;
            }
            if i <= idx <= j {
              assert decreasing(arr[idx..]);
              decreasing_aux_lemma(arr[j], arr[idx..]);
              assert arr[idx] >= res[k] by {
                assert arr[idx] >= arr[j];
              }
            }
          }
          assert m[k] in multiset(arr[k..]) by {
            assert m[k] in multiset(m[k..]);
          }
          assert false by {
           assert arr[k] < m[k];
           assert res[k] <= m[k];
          }
        }
      }
    }
  }
```

Finally we arrive at case when `k` is equal `i-1`. It requires further case analysis. If `m[k]` is equal to 
`res[k]` then `multiset(m[(k+1)..])` is equal to `multiset(res[(k+1)..])`. By using 
`increasing_multiset_aux_lemma` which states that increasing sequence is smallest among sequences 
generated from multiset we complete the proof. Case `m[k]` is less than `res[k]` is also impossible 
as we picked smallest element greater than `res[k]` in `multiset(arr[k..])` to replace it with. 
Using `forall` statement we remind Dafny of this fact. Establishing false follows similiar pattern 
as earlier contradiction.

Final verified program with all auxiliary lemma is listed [here](https://gist.github.com/rdivyanshu/c7ced3c3ff2bfc9c3cc38b2cae6609f0). That's all.