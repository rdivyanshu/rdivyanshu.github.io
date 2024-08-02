---   
title: Streams, Calculational Proofs and Dafny
date-meta: 2024-08-02
description-meta: Reasoning about infinite streams using coinduction and Dafny
---

## Introduction

Calculational proof where chain of equality is established to show first and last statement are equal 
is an elegant way to write proof. For example

~~~{.default}
  (a + b) ^ 2 
= (a + b) * (a + b) 
= a * (a + b) + b * (a + b)
= a ^ 2 + a * b + b * a + b ^ 2 
= a ^ 2 + a * b + a * b + b ^ 2 
= a ^ 2 + 2 * a * b + b ^ 2
~~~

Dafny has support for writing calculational proof using `calc`. Following 
proof shows that `Append(Repeat(m, elm), Repeat(n, elm))` is equal to `Repeat(m + n, elm)`.

~~~{.dafny}
datatype List<T> = Nil | Cons(head: T, tail: List<T>)

function Repeat<T>(n: nat, elm: T) : List <T>
{
   if n == 0 then Nil else Cons(elm, Repeat(n - 1, elm))
}

function Append<T>(s: List<T>, t: List<T>) : List<T> 
{
    if s == Nil then t else Cons(s.head, Append(s.tail, t))
}

lemma RepeatAppend<T>(m: nat, n: nat, elm: T)
   ensures Append(Repeat(m, elm), Repeat(n, elm)) == Repeat(m + n, elm)
{
    if m == 0 {
      calc {
        Append(Repeat(m, elm), Repeat(n, elm));
        Append(Repeat(0, elm), Repeat(n, elm));
        Append(Nil, Repeat(n, elm));
        Repeat(n, elm);
        Repeat(0 + n, elm);
        Repeat(m + n, elm);
      }
    }
    else {
      calc {
        Append(Repeat(m, elm), Repeat(n, elm));
        Append(Cons(elm, Repeat(m - 1, elm)), Repeat(n, elm));
        Cons(elm, Append(Repeat(m - 1, elm), Repeat(n, elm)));
        { RepeatAppend(m - 1, n, elm); }
        Cons(elm, Repeat(m - 1 + n, elm));
        Repeat(1 + m - 1 + n, elm);
        Repeat(m + n, elm);
      }
    }
}
~~~

Notice use of inductive hypothesis to show `Append(Repeat(m - 1, elm), Repeat(n, elm)) = Repeat(m - 1 + n, elm)`.
Otherwise rewrite between previous and current statement follows from definition.

## Calculational reasoning about Stream

List is inductive datatype which means that induction as proof strategy is available when writing 
calculational proof. This is not case with stream which is coinductive datatype.

~~~{.dafny}
codatatype Stream = Cons(head: nat, tail: Stream)
~~~

Consider `Nats()` (natural numbers), it is trivial to check that `Nats()` is not equal to 
`Add(Nats(), Repeat(1))` -- just compare the head of both streams. However `Nats()`
is equal to `Alternate(Mul(Repeat(2), Nats()), Add(Mul(Repeat(2), Nats()), Repeat(1)))` but it is
not obvious how to establish it without induction.

~~~{.dafny}
function Upwards(n: nat): Stream {
   Cons(n, Upwards (n + 1))
}

function Nats() : Stream {
    Upwards(0)
}

function Repeat(n: nat) : Stream {
    Cons(n, Repeat(n))
}

function Add(s: Stream, t: Stream) : Stream {
    Cons(s.head + t.head, Add(s.tail, t.tail))
}

function Mul(s: Stream, t: Stream): Stream {
    Cons(s.head * t.head, Mul(s.tail, t.tail))
}

function Alternate(s: Stream, t: Stream): Stream {
    Cons(s.head, Alternate(t, s.tail))
}
~~~

[This paper](http://aszt.inf.elte.hu/~cefp2009/materials/papers/Hinze.pdf) endorses a proof 
strategy which is based on the fact that restricted stream equations have unique solution. All streams
satisfy `s = Cons(s.head, s.tail)` whereas `s = s.tail` is satisfied by `Repeat(k)` for every `k`.
Only solution of `s = Cons(1, s)` is `Repeat(1)` since it is kind of restricted equation
paper is talking about. To prove two streams are equal it is enough to show that they satisfy
same restricted equation.

## Calculational reasoning about Stream in Dafny

We will first prove that `s == Cons(0, Add(Repeat(1), s))` has a unique solution `Nats()`.  This
requires formulating `UpwardsUniqueFixedPoint` which is enough. Under the hood, Dafny is doing heavy lifting
of finding proof. Only thing we are signaling to Dafny is that lemma is about `codatatype` by mentioning 
`greatest` before `lemma`. 

~~~{.dafny}
greatest lemma UpwardsUniqueFixedPoint(t: nat, s: Stream) 
   requires s == Cons(t, Add(Repeat(1), s))
   ensures s == Upwards(t)
{}

lemma NatsUniqueFixedPoint(s: Stream)
   requires s == Cons(0, Add(Repeat(1), s))
   ensures s == Nats()
{
    UpwardsUniqueFixedPoint(0, s);
}
~~~

Next we will write calculation style proof to show that `Alternate(Mul(Repeat(2), Nats()), Add(Mul(Repeat(2), Nats()), Repeat(1)))`
satisfies the same equation. This requires few more lemmas which Dafny is able to prove by itself. 

~~~{.dafny}
lemma UniqueFixedPointApplication()
   ensures Nats() == Alternate(Mul(Repeat(2), Nats()), 
                               Add(Mul(Repeat(2), Nats()), Repeat(1)))
{
   var s := Nats();
   var t := Repeat(2);
   var u := Repeat(1);
   calc {
      Alternate(Mul(t, s), Add(Mul(t, s), u));
      Cons(0, Alternate(Add(Mul(t, s), u), (Mul(t, s)).tail));
      Cons(0, Alternate(Add(Mul(t, s), u), (Mul(t.tail, s.tail))));
      Cons(0, Alternate(Add(Mul(t, s), u), (Mul(t, s.tail))));
      Cons(0, Alternate(Add(Mul(t, s), u), (Mul(t, Upwards(0).tail))));
      { UpwardsLemma(0); }
      Cons(0, Alternate(Add(Mul(t, s), u), (Mul(t, (Cons(0, Add(u, s))).tail))));
      Cons(0, Alternate(Add(Mul(t, s), u), (Mul(t, Add(u, s)))));
      { MulRepeatAddLemma(2, 1, s); }
      Cons(0, Alternate(Add(Mul(t, s), u), Add(t, Mul(t, s))));
      { AddLemma(Mul(t, s), t); }
      Cons(0, Alternate(Add(Mul(t, s), u), Add(Mul(t, s), t)));
      { AddSplitLemma(1, 1, Mul(t, s)); }
      Cons(0, Alternate(Add(Mul(t, s), u), Add(Add(Mul(t, s), u), u)));
      { AlternateLemma(Mul(t, s), Add(Mul(t, s), u), 1); }
      Cons(0, Add(Alternate(Mul(t, s), Add(Mul(t, s), u)), u));
   }
   var m := Alternate(Mul(t, s), Add(Mul(t, s), u));
   assert m == Cons(0, Add(m, u));
   AddLemma(m, Repeat(1));
   assert m == Cons(0, Add(u, m));
   NatsUniqueFixedPoint(m);
}
~~~

This is the [gist](https://gist.github.com/rdivyanshu/2042085421d5f0762184dd7fe7cfb4cb) to play with proof. 
I have also provided manual proof of `UpwardsUniqueFixedPoint` in comments. Surprise, it depends on (transfinite)
induction as Dafny approaches coinduction proof via induction ([paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/coinduction.pdf)). 





