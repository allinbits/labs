package events

var GnoLandLaunchREADME = `
## Gno.land Launch Realm

Welcome to the **Gno.land Launch** realm!  
This is your home for everything related to our big kickoff event.

---

## I. Overview

1. **Gno.land Launch Event Realm Structure** 
	+ The main realm is r/buidlthefuture000/events/gnolandlaunch. This is where the event info and agenda live. 
	+ The sub relam is r/buidlthefuture000/events/gnolandlaunch/proposals. Read the Proposals README for more info.

2. **Main realm features**
	+ **Agenda**: Browse the full event schedule.
	+ **Speakers**: See profiles and bios for the registered speakers. 
	+ **Raw objects**: Append :json to any path (or leave it blank) to fetch the same data as JSON instead of Markdown.

3. **Join the conversation**
	+ Want to attend? Join the waitlist! Want to propose a session? Join the waitlist!
       1. Head over to the main realm and use the Register to Attend button to join the waitlist.
       2. You should also join the event's discord or checkout the event's boards thread to meet others and ask questions. 

   [Join Waitlist](https://www.youtube.com/watch?v=xvFZjo5PgG0)  
   [Chat on Discord](https://www.youtube.com/watch?v=xvFZjo5PgG0)

---

## II. Calendar (Coming Soon)

We’re working on a “Download iCal” button so you can:

    // in your future code:
    DownloadAgendaICal()

and instantly import the full event schedule into your calendar app.

---

## III. Explorer Tips

- To render only a certain object (e.g. event:0), modifiy the realm by appending :[object]:[number]  
- It renders to markdown by default. To see it as JSON, append :json to the path.  
- Below is a list of objects you can render alone and what to type to get them:

      :location:<id>(:json)     →  Location details  
      :speaker:<id>(:json)      →  Speaker profile  
      :event:<id>(:json)        →  Full agenda  

- The :json in parentheses means that it is optional. 

Enjoy the launch—and happy building!  
`

var ProposalsREADME = `
## Proposals Realm

Welcome to the **Buidl The Future 2025 Call For Proposals Realm!**  
Here is where prospective session proposers can go to submit their proposals to the event.

---

## I. Quick Walkthrough

1. **Introduction**  
   Using the proposals realm requires your gno address to have the appropriate roles. There are three different roles on the proposals realm:
   Organizer, Reviewer, and Proposer. To get a role, you must reach out to the event organizer and request a role. Once they add your address to the 
   role list, you can use all the buttons you have permission to use!

2. **Session Topics**  
   - If you’re a **proposer**, start by looking in the Proposal Topics section for a session topic that appeals to you.
   - There are seven topics to choose from: (1) Privacy, Security & Identity; (2) Information, Media & Social Infrastructure; (3) Governance & Regulation; (4) Infrastructure, Tools & Developer UX; (5) Gno.land & The Logoverse; (6) The Intersection of AI & Web3; and (7) Secure Home Computing.
   - These topics are to showcase how gno.land can support the promises of web3 and a decentralized web.

3. **Submitting a Proposal**  
   - When ready, use the **Submit a [Session Topic] Proposal** button. It will open an Adena Wallet window to a submit a proposal command that already has the topic parameter filled out.
   - Fill in **Title**, **Abstract**, **Speaker**—put in your password to use the SubmitProposal(...) command.  
   - You can always edit your submission after posting it, or you can ask an organizer to fix a typo etc.
   - Check if your submission went through by finding your proposal in the Submitted Proposals section of the realm.

4. **Reviewing & Approving**  
    - As a **reviewer**:  
     1. Click **Review** to open a pre-filled ReviewProposal(title, comments, reviewer, score) command in Adena Wallet. Enter your feedback and score, then submit.  
     2. Click **Approve** to pre-fill ApproveProposal(title, approver). Confirm to move that proposal to **Approved Proposals**.  
   - As an **organizer**, you inherit all reviewer actions plus batch operations:  
     - Use **Approve** for single proposals or **Approve All** (via ApproveProposals(titles []string, approver)) to process multiple titles at once.

5. **Exporting & Rendering**  
    - After all approvals are finalized, run:  
     ExportApprovedProposals()
     This will be how the event realm can grab the approved proposals so they can fit them in to the final agenda.

---


## II. Roles & Actions

### Proposers
- **Submit** a new proposal  
  SubmitProposal(title string, abstract string, topic string, speaker string)
  Choose one of our topic tracks and provide a concise abstract.

- **Edit** any proposal  
  EditProposal(title string, key string, edit string)
  You can only edit your own proposal, unless you are an organizer. The key field could be "title", "abstract", "topic", or "speaker"

### Reviewers
- **Review** and rate proposals (once elected)  
  ReviewProposal(title string, comments string, reviewer string, score int)
  Supply constructive feedback and a numeric score to help shape the program.

### Organizers
All the powers of proposers & reviewers, plus:
- **Approve** single proposals  
  ApproveProposal(title string, approver string)
- **Approve** multiple at once  
  ApproveProposals(titles []string, approver string)
- **Edit** any proposal  
  EditProposal(title string, key string, edit string)
- **Export** the final list  
  ExportApprovedProposals()

---
`

func Render(path string) string {
	return GnoLandLaunchREADME + "\n\n---\n\n" + ProposalsREADME
}
