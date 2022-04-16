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
        token: Token, // ex goETH
        decimals: UInt, // ex dec1:
        token2: Token, // ex goETH
        decimals2: UInt, // ex dec1:
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
  }),
];
export const Api = () => [
  API({
    touch: Fun([], Null),
    getBid: Fun([UInt], Null),
    getBidWithToken: Fun([UInt], Null),
    updateToken: Fun([UInt], Null),
    getBidWithToken2: Fun([UInt], Null),
    updateToken2: Fun([UInt], Null),
    close: Fun([], Null),
  }),
];
export const App = (map) => {
  const [[Manager, Relay], [v], [a]] = map;
  Manager.only(() => {
    const { oracle, token, decimals, token2, decimals2 } = declassify(interact.getParams());
    assume(distinct(token, token2))
  });
  Manager.publish(oracle, token, decimals, token2, decimals2);
  require(distinct(token, token2))
  v.currentPrice.set(0);
  v.amount.set(0);
  v.token.set(token);
  v.decimals.set(decimals);
  v.amount2.set(0);
  v.token2.set(token2);
  v.decimals2.set(decimals2);
  // ---------------------------------------------
  // TODO allow manager or controller to update amount
  // ---------------------------------------------
  const [keepGoing, hb, c0, c1, c2, a1, a2] = parallelReduce([true, Manager, 0, 0, 0, 0, 0])
    .define(() => {
      v.currentPrice.set(c0);
      v.amount.set(a1);
      v.amount2.set(a2);
    })
    .invariant(balance() >= 0)
    .while(keepGoing)
    .paySpec([token, token2])
    .api(
      a.touch,
      () => assume(true),
      () => [0, [0, token], [0, token2]],
      (k) => {
        require(true);
        k(null);
        return [true, hb, c0, c1, c2, a1, a2];
      }
    )
    .api(
      a.getBid,
      (m) => assume(m > c0),
      (m) => [m, [0, token], [0, token2]],
      (m, k) => {
        require(m > c0);
        transfer(balance(token2), token2).to(hb);
        transfer(balance(token), token).to(hb);
        transfer(balance()-m).to(hb);
        k(null);
        return [true, this, m, c1, c2, a1, a2];
      }
    )
    .api(
      a.getBidWithToken,
      (m) => assume((m * a1) / decimals > c0),
      (m) => [0, [m, token], [0, token2]],
      (m, k) => {
        require((m * a1) / decimals > c0);
        k(null);
        transfer(balance(token2), token2).to(hb);
        transfer(balance(token)-m, token).to(hb);
        transfer(balance()).to(hb);
        return [true, this, (m * a1) / decimals, m, c2, a1, a2];
      }
    )
    .api(
      a.updateToken,
      (_) => assume(true),
      (_) => [0, [0, token], [0, token2]],
      (m, k) => {
        require(true);
        k(null);
        const bal = balance(token);
        if (bal > 0) {
          return [true, hb, (c1 * m) / decimals, c1, c2, m, a2];
        } else {
          return [true, hb, c0, c1, c2, m, a2];
        }
      }
    )
    .api(
      a.getBidWithToken2,
      (m) => assume((m * a2) / decimals2 > c0),
      (m) => [0, [0, token], [m, token2]],
      (m, k) => {
        require((m * a2) / decimals2 > c0);
        k(null);
        transfer(balance(token2)-m, token2).to(hb);
        transfer(balance(token), token).to(hb);
        transfer(balance()).to(hb);
        return [true, this, (m * a2) / decimals2, c1, m, a1, a2];
      }
    )
    .api(
      a.updateToken2,
      (_) => assume(true),
      (_) => [0, [0, token], [0, token2]],
      (m, k) => {
        require(true);
        k(null);
        const bal = balance(token2);
        if (bal > 0) {
          return [true, hb, (c2 * m) / decimals2, c1, c2, a1, m];
        } else {
          return [true, hb, c0, c1, c2, a1, m];
        }
      }
    )
    .api(
      a.close,
      () => assume(true),
      () => [0, [0, token], [0, token2]],
      (k) => {
        require(true);
        k(null);
        return [false, hb, c0, c1, c2, a1, a2];
      }
    )
    .timeout(false);
  // ---------------------------------------------
  commit();
  Relay.publish();
  transfer(balance()).to(Relay);
  transfer(balance(token), token).to(Relay);
  transfer(balance(token2), token2).to(Relay);
  commit();
  exit();
};
// ----------------------------------------------
