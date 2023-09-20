# Dynamic frames in Dafny

## Introduction
There are two kind of types in dafny: value types and reference types. Reference types are
allocated dynamically in heap - these includes array and class. Reasoning about value type is
easier by virtue of their immutablility. On the other hand refernce type can change values
- hence reasoning about them entales going through call traces to expose locations where they are changed
if any. Dafny uses dynamic frames as foundation for reference type
reasoning - it requires for every method it has to list reference type it can modify. 

This is how it will look like in code:

```
method copy<T>(src: array<T>, dest<T>)
 modifies dest
 requires src.Length == dest.Length
 ensures forall i :: 0 <= i < src.Length ==> src[i] == dest[i]
{ ... }

```

It makes dafny compiler
job easier if reference type is not in modifies list of method call we can assume value of reference type is 
same after call.

```
method Print(arr: array<int>)
{ ... }

method Main(){
  var arr: array<int> = ....
  assert forall i :: 0 <= i < arr.Lenth ==> arr[i] >= 0;
  Print(arr);
  assert forall i :: 0 <= i < arr.Length ==> arr[i] >= 0;
}

```

If first assert in above code holds then it can reason that second assert should also hold as arr is not modified by Print.

Giving method's modifies and requires clause is little nauched in presence of reference types.

## Pointer Alias

Consider following code - one generally hopes that below code should verify. But dafny complains loudly about it.

```
void update(arr: array< array<int> >, i: nat, j: nat, val: int)
  modifies arr
  requires 0 <= i < arr.Length && 0 <= j < arr[i].Length
  ensures forall i, j :: 0 <= i < arr.Length && 0 <= j < arr[i].Length ==> (
    (i == i) && (j == j) || arr[i][j] == old(arr[i][j]))
  ensures arr[i][j] == val
{
    arr[i][j] := val;
}

```

Problem here is pointer alias - if say arr is of length 3 and first and second index point to same array.
Call to update(arr, 0, 0, 1) means arr[1][0] is now also become 1 - hence old(arr[1][0]) == arr[1][0] does
n't hold. If your arr does n't contains pointer alias you can modify require to inform dafny that - so it 
can verify.

```
void update(arr: array< array<int> >, i: nat, j: nat, val: int)
  modifies arr
  requires forall i, j :: 0 <= i < j < arr.Length ==> arr[i] != arr[j]
  requires 0 <= i < arr.Length && 0 <= j < arr[i].Length
  ensures forall i, j :: 0 <= i < arr.Length && 0 <= j < arr[i].Length ==> (
    (i == i) && (j == j) || arr[i][j] == old(arr[i][j]))
  ensures arr[i][j] == val
{
    arr[i][j] := val;
}
```

## Insufficient Modifies Clauses
