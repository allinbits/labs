# Events System

## Ambient Event Space

![ND Constraints Visualization][n-dimensional-space]

Imagine the ambient space is the space of all possible events.  
If the space only had three constraints, each event could be visualized as a little volume cube like above.  
This concept scales into higher dimensions, offering a helpful geometric intuition.

## Event System from a User Perspective

- Imagine opening your phone or PC and navigating to [https://btf.com/events](https://btf.com/events) to see a calendar view of the current month’s events.  
- You could search through these events much like you browse locations in Google Maps:

![Event Search Demo][google-maps-search]

## Stable Matching

A **matching** is a pair `(audience: []Bid, organizer: EventProposal)` such that neither the audience nor the organizer would prefer switching to any other pair—i.e. no `(audience, organizer')` or `(audience', organizer)` is strictly better for both.

- The simplest case is when every audience member and every organizer can totally rank the other side.
- In a decentralized bid-relaying context you don’t always have total orderings, but partial orderings can still yield stable outcomes.
- **Non-greedy markets** could start as soon as their minimum requirements are met and audience intent is maximized, resulting in a stable match right away.
- **Greedy markets** might wait to maximize revenue, potentially leaving some bids unfilled.  Partial-ordering strategies can help navigate such trade-offs.

---

[n-dimensional-space]: images/n-dimensional_space.png  
[google-maps-search]: https://storage.googleapis.com/gweb-mapsplatform-cdn/uploads/lq6qgs6wvqjt-6YeQjQN1jxkJhplGoT35MU-42cf94c0f14459213cb1e064bcd8bee9-zoom_gradation_pLnbdI1.gif  
