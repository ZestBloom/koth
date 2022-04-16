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
        token: Token, // ex goETH
        decimals: UInt, // ex dec1:
      })
    ),
  }),
  Participant("Relay", {}),
];
export const Views = () => [
  View({
    amount: UInt,
    token: Token, // ex goETH
    decimals: UInt, // ex dec1
    currentPrice: UInt,
  }),
];
export const Api = () => [
  API({
    touch: Fun([], Null),
    getBid: Fun([UInt], Null),
    getBidWithToken: Fun([UInt], Null),
    updateToken: Fun([UInt], Null),
    close: Fun([], Null),
  }),
];
export const App = (map) => {
  const [[Manager, Relay], [v], [a]] = map;
  Manager.only(() => {
    const { oracle, token, decimals } = declassify(interact.getParams());
  });
  Manager.publish(oracle, token, decimals);
  v.currentPrice.set(0);
  v.amount.set(0);
  v.token.set(token);
  // ---------------------------------------------
  // TODO allow manager or controller to update amount
  // ---------------------------------------------
  const [keepGoing, hb, c0, c1, a1] = parallelReduce([true, Manager, 0, 0, 0])
    .define(() => {
      v.currentPrice.set(c0);
      v.amount.set(a1);
    })
    .invariant(balance() >= 0)
    .while(keepGoing)
    .paySpec([token])
    .api(
      a.touch,
      () => assume(true),
      () => [0, [0, token]],
      (k) => {
        require(true);
        k(null);
        return [true, hb, c0, c1, a1];
      }
    )
    .api(
      a.getBid,
      (m) => assume(m > c0),
      (m) => [m, [0, token]],
      (m, k) => {
        require(m > c0);
        transfer(balance()-m).to(hb);
        transfer(balance(token), token).to(hb);
        k(null);
        return [true, this, m, 0, a1];
      }
    )
    .api(
      a.getBidWithToken,
      (m) => assume((m * a1) / decimals > c0),
      (m) => [0, [m, token]],
      (m, k) => {
        require((m * a1) / decimals > c0);
        k(null);
        transfer(balance(token)-m, token).to(hb);
        transfer(balance()).to(hb);
        return [true, this, (m * a1) / decimals, m, a1];
      }
    )
    .api(
      a.updateToken,
      (_) => assume(true),
      (_) => [0, [0, token]],
      (m, k) => {
        require(true);
        k(null);
        const bal = balance(token);
        if (bal > 0) {
          return [true, hb, (c1 * m) / decimals, c1, m];
        } else {
          return [true, hb, c0, c1, m];
        }
      }
    )
    .api(
      a.close,
      () => assume(true),
      () => [0, [0, token]],
      (k) => {
        require(true);
        k(null);
        return [false, hb, c0, c1, a1];
      }
    )
    .timeout(false);
  // ---------------------------------------------
  commit();
  Relay.publish();
  transfer(balance()).to(Relay);
  transfer(balance(token), token).to(Relay);
  commit();
  exit();
};
// ----------------------------------------------
