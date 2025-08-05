WIP
---
High level TODOs for eve

- [ ] Focus on separation between Event -> Flyer objects for security and developer api
- [ ] Refine ACL to make it more flexible between the different example events
- [ ] Test /events api with all registered events
- [ ] Audit for security issues with event permissions re: realm-based perms
- [ ] add rendering tests for each type of supported event config location/speaker/cancelled events

Consider a possible work-around for inability to share directly
- we could integrate w/ google calendar - manually importing and ICS then sharing that link

BACKLOG
-------

- [ ] test ICS integration with gnocal server
- [ ] make sure HasRole and RenderCalendar are available at proper realms
- [ ] add URL pointers for aiblabs domain (for testing on aiblabs.com)
- [ ] fix event.ToJsonLD() to populate all fields states
- [ ] update gnocal server to have a landing page in html, SVG + w/ jsonLD nested for structured data
- [ ] fix/test the `/events` api
- [ ] consider refactoring acl.gno for each event's specific needs
- [ ] review style of events in calendar (url encoded? Test+foo ?)
- [ ] self-audit patch permissions for each event's realm 
- [ ] test content blocks with callbacks
 
DONE
-----