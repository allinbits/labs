WIP
---
- [ ] test ICS integration with gnocal server
- [ ] make sure HasRole and RenderCalendar are available at proper realms
- [ ] add URL pointers for aiblabs domain (for testing on aiblabs.com)
- [ ] fix event.ToJsonLD() to populate all fields states

BACKLOG
-------
 
- [ ] update gnocal server to have a landing page in html, SVG + w/ jsonLD nested for structured data
- [ ] fix/test the `/events` api
- [ ] consider refactoring acl.gno for each event's specific needs
- [ ] review style of events in calendar (url encoded? Test+foo ?)
- [ ] self-audit patch permissions for each event's realm - is exposing LiveEvent() bad?
- [ ] test content blocks with callbacks
 
DONE
-----
- [x] fix http://127.0.0.1:8888/r/buidlthefuture000/events/onsite001?format=ics
- [x] finish refactoring component.RenderPage - we now have registery.Render() involved calling component...
- [x] add version number to bottom of /events page

