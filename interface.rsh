"reach 0.1";
"use strict";
// -----------------------------------------------
// Name: Interface Template
// Description: NP Rapp simple
// Author: Nicholas Shellabarger
// Version: 0.0.2 - initial
// Requires Reach v0.1.7 (stable)
// ----------------------------------------------
export const Participants = () => [
  Participant("Manager", {
    getParams: Fun(
      [],
      Object({
        oracle: Contract, // ex knows goETH ALGO perr unit
        oracle2: Contract, // ex knows goETH ALGO perr unit
        oracle3: Contract, // ex knows goETH ALGO perr unit
        token: Token, // ex goETH
        decimals: UInt, // ex dec1:
        token2: Token, // ex goETH
        decimals2: UInt, // ex dec1:
        token3: Token, // ex goETH
        decimals3: UInt, // ex dec1:
      })
    ),
  }),
  Participant("Relay", {}),
];
export const Views = () => [
  View({
    currentPrice: UInt,
    amount: UInt, // ex ALGO per goETH
    token: Token, // ex goETH
    decimals: UInt, // ex dec1
    amount2: UInt, // ex ALGO per goBTC
    token2: Token, // ex goETH
    decimals2: UInt, // ex dec1
    amount3: UInt, // ex ALGO per goBTC
    token3: Token, // ex goETH
    decimals3: UInt, // ex dec1
  }),
];
export const Api = () => [
  API({
    touch: Fun([UInt], Null),
    getBid: Fun([UInt], Null),
    getBidWithToken: Fun([UInt], Null),
    updateToken: Fun([UInt], Null),
    updateTokenUsingOracle: Fun([], Null),
    getBidWithToken2: Fun([UInt], Null),
    updateToken2: Fun([UInt], Null),
    updateToken2UsingOracle: Fun([], Null),
    getBidWithToken3: Fun([UInt], Null),
    updateToken3: Fun([UInt], Null),
    updateToken3UsingOracle: Fun([], Null),
    close: Fun([], Null),
  }),
];
export const App = (map) => {
  const [[Manager, Relay], [v], [a]] = map;
  Manager.only(() => {
    const {
      oracle,
      oracle2,
      oracle3,
      token,
      decimals,
      token2,
      decimals2,
      token3,
      decimals3,
    } = declassify(interact.getParams());
    assume(distinct(token, token2, token3));
  });
  Manager.publish(
    oracle,
    oracle2,
    oracle3,
    token,
    decimals,
    token2,
    decimals2,
    token3,
    decimals3
  );
  require(distinct(token, token2, token3));
  v.currentPrice.set(0);
  v.amount.set(0);
  v.token.set(token);
  v.decimals.set(decimals);
  v.amount2.set(0);
  v.token2.set(token2);
  v.decimals2.set(decimals2);
  v.amount3.set(0);
  v.token3.set(token3);
  v.decimals3.set(decimals3);
  // ---------------------------------------------
  // TODO allow manager or controller to update amount
  // ---------------------------------------------
  const [keepGoing, hb, c0, c1, c2, c3, a1, a2, a3] = parallelReduce([
    true,
    Manager,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ])
    .define(() => {
      v.currentPrice.set(c0);
      v.amount.set(a1);
      v.amount2.set(a2);
      v.amount3.set(a3);
    })
    .invariant(balance() >= 0)
    .while(keepGoing)
    .paySpec([token, token2, token3])
    .api(
      a.touch,
      (_) => assume(true),
      (_) => [0, [0, token], [0, token2], [0, token3]],
      (m, k) => {
        require(true);
        k(null);
        const whichToken = m % 3;
        if (whichToken == 0) {
          const rCtc = remote(oracle, { amount: Fun([], UInt) });
          const amt = rCtc.amount();
          return [true, hb, c0, c1, c2, c3, amt, a2, a3];
        } else if (whichToken == 1) {
          const rCtc = remote(oracle2, { amount: Fun([], UInt) });
          const amt = rCtc.amount();
          return [true, hb, c0, c1, c2, c3, a1, amt, a3];
        } else if (whichToken == 2) {
          const rCtc = remote(oracle3, { amount: Fun([], UInt) });
          const amt = rCtc.amount();
          return [true, hb, c0, c1, c2, c3, a1, a2, amt];
        } else {
          return [true, hb, c0, c1, c2, c3, a1, a2, a3];
        }
      }
    )
    .api(
      a.getBid,
      (m) => assume(m > c0),
      (m) => [m, [0, token], [0, token2], [0, token3]],
      (m, k) => {
        require(m > c0);
        transfer(balance(token3), token3).to(hb);
        transfer(balance(token2), token2).to(hb);
        transfer(balance(token), token).to(hb);
        transfer(balance() - m).to(hb);
        k(null);
        return [true, this, m, c1, c2, c3, a1, a2, a3];
      }
    )
    .api(
      a.getBidWithToken,
      (m) => assume((m * a1) / decimals > c0),
      (m) => [0, [m, token], [0, token2], [0, token3]],
      (m, k) => {
        require((m * a1) / decimals > c0);
        k(null);
        transfer(balance(token3), token3).to(hb);
        transfer(balance(token2), token2).to(hb);
        transfer(balance(token) - m, token).to(hb);
        transfer(balance()).to(hb);
        return [true, this, (m * a1) / decimals, m, c2, c3, a1, a2, a3];
      }
    )
    .api(
      a.updateToken,
      (_) => assume(true),
      (_) => [0, [0, token], [0, token2], [0, token3]],
      (m, k) => {
        require(true);
        k(null);
        const bal = balance(token);
        if (bal > 0) {
          return [true, hb, (c1 * m) / decimals, c1, c2, c3, m, a2, a3];
        } else {
          return [true, hb, c0, c1, c2, c3, m, a2, a3];
        }
      }
    )
    .api(
      a.updateTokenUsingOracle,
      () => assume(true),
      () => [0, [0, token], [0, token2], [0, token3]],
      (k) => {
        require(true);
        k(null);
        const rCtc = remote(oracle, { amount: Fun([], UInt) })
        const amt = rCtc.amount()
        const bal = balance(token);
        if (bal > 0) {
          return [true, hb, (c1 * amt) / decimals, c1, c2, c3, amt, a2, a3];
        } else {
          return [true, hb, c0, c1, c2, c3, amt, a2, a3];
        }
      }
    )
    .api(
      a.getBidWithToken2,
      (m) => assume((m * a2) / decimals2 > c0),
      (m) => [0, [0, token], [m, token2], [0, token3]],
      (m, k) => {
        require((m * a2) / decimals2 > c0);
        k(null);
        transfer(balance(token3), token3).to(hb);
        transfer(balance(token2) - m, token2).to(hb);
        transfer(balance(token), token).to(hb);
        transfer(balance()).to(hb);
        return [true, this, (m * a2) / decimals2, c1, m, c3, a1, a2, a3];
      }
    )
    .api(
      a.updateToken2,
      (_) => assume(true),
      (_) => [0, [0, token], [0, token2], [0, token3]],
      (m, k) => {
        require(true);
        k(null);
        const bal = balance(token2);
        if (bal > 0) {
          return [true, hb, (c2 * m) / decimals2, c1, c2, c3, a1, m, a3];
        } else {
          return [true, hb, c0, c1, c2, c3, a1, m, a3];
        }
      }
    )
    .api(
      a.updateToken2UsingOracle,
      () => assume(true),
      () => [0, [0, token], [0, token2], [0, token3]],
      (k) => {
        require(true);
        k(null);
        const rCtc = remote(oracle2, { amount: Fun([], UInt) })
        const amt = rCtc.amount()
        const bal = balance(token2);
        if (bal > 0) {
          return [true, hb, (c2 * amt) / decimals2, c1, c2, c3, a1, amt, a3];
        } else {
          return [true, hb, c0, c1, c2, c3, a1, amt, a3];
        }
      }
    )
    .api(
      a.getBidWithToken3,
      (m) => assume((m * a3) / decimals3 > c0),
      (m) => [0, [0, token], [0, token2], [m, token3]],
      (m, k) => {
        require((m * a3) / decimals3 > c0);
        k(null);
        transfer(balance(token3) - m, token3).to(hb);
        transfer(balance(token2), token2).to(hb);
        transfer(balance(token), token).to(hb);
        transfer(balance()).to(hb);
        return [true, this, (m * a3) / decimals3, c1, c2, m, a1, a2, a3];
      }
    )
    .api(
      a.updateToken3,
      (_) => assume(true),
      (_) => [0, [0, token], [0, token2], [0, token3]],
      (m, k) => {
        require(true);
        k(null);
        const bal = balance(token3);
        if (bal > 0) {
          return [true, hb, (c3 * m) / decimals3, c1, c2, c3, a1, a2, m];
        } else {
          return [true, hb, c0, c1, c2, c3, a1, a2, m];
        }
      }
    )
    .api(
      a.updateToken3UsingOracle,
      () => assume(true),
      () => [0, [0, token], [0, token2], [0, token3]],
      (k) => {
        require(true);
        k(null);
        const rCtc = remote(oracle3, { amount: Fun([], UInt) })
        const amt = rCtc.amount()
        const bal = balance(token3);
        if (bal > 0) {
          return [true, hb, (c3 * amt) / decimals3, c1, c2, c3, a1, a2, amt];
        } else {
          return [true, hb, c0, c1, c2, c3, a1, a2, amt];
        }
      }
    )
    .api(
      a.close,
      () => assume(true),
      () => [0, [0, token], [0, token2], [0, token3]],
      (k) => {
        require(true);
        k(null);
        return [false, hb, c0, c1, c2, c3, a1, a2, a3];
      }
    )
    .timeout(false);
  // ---------------------------------------------
  commit();
  Relay.publish();
  transfer(balance()).to(Relay);
  transfer(balance(token), token).to(Relay);
  transfer(balance(token2), token2).to(Relay);
  transfer(balance(token3), token3).to(Relay);
  commit();
  exit();
};
// ----------------------------------------------
