# Swift Recall Kit

One search across everything said and written on a Mac — Mail, Messages,
WhatsApp and Notes — by words, by person, or both. Read-only, on this Mac:
each source is read through its own library, nothing is sent or kept.

```swift
import RecallKit

let found = try Recall.search(RecallQuery(text: "boiler", person: "Alex", since: lastMonth))
for hit in found.hits {
    print(hit.date, hit.source, hit.from ?? "", hit.title ?? "", hit.excerpt)
}
found.found     // [.mail: 3, .messages: 7, .whatsapp: 0]
found.skipped   // [notes: notes have no sender]
found.person    // names: ["Alex Rivera"], phones: [...], emails: [...]
```

| Source | Read through | Matched on |
|---|---|---|
| Mail | [swift-apple-mail](https://github.com/arraypress/swift-apple-mail) | subject and sender; with `bodies`, the newest message files too |
| Messages | [swift-apple-messages](https://github.com/arraypress/swift-apple-messages) | the message text, including text Messages keeps only in its rich form |
| WhatsApp | [swift-whatsapp-messages](https://github.com/arraypress/swift-whatsapp-messages) | text, captions, file names and link titles |
| Notes | [swift-apple-notes](https://github.com/arraypress/swift-apple-notes) | title and opening lines; with `bodies`, whole notes |

## A person is every address they have

A phone number or email address is searched as itself. A name is looked up in
Contacts ([swift-contacts](https://github.com/arraypress/swift-contacts)) and
every phone and email of every contact it matches is searched — the Messages
database holds addresses, never names. WhatsApp keeps its own names (the
address book's, the ones people chose for themselves), so its directory is
asked too, and each address is searched with its pair (WhatsApp gives some
people a second, `@lid`, address). Mail is searched by the person's email
addresses, or by name when Contacts has none. Notes have no sender: a person
search skips them, and says so.

## Nothing found is not the same as not looked

A source that can't be read — no Full Disk Access, WhatsApp not installed,
Contacts refused — is a `RecallSkip` with its reason, and the rest still
answer. Only when no source can be read does the search throw
(`RecallError.nothingSearched`, every reason listed). `Recall.availability()`
opens each store and closes it again, to say up front what can be read.

## Bodies

Mail's index holds subjects and senders, not bodies, and Spotlight indexes no
mail (measured in swift-apple-mail, which also found two-thirds of an IMAP
mailbox's bodies are not on the Mac at all). With `bodies: true`, the newest
`bodyBudget` candidates (500 by default) are read and searched; those only on
the server are counted in `unreadBodies`, not passed over in silence. Notes are
decoded whole the same way.

## Results

Hits from every source are merged newest first and cut to `limit`; a row found
twice (a person searched by two addresses) counts once, and ties sort by source
then row, so the same search prints the same list. Each hit carries its row in
its own store and its conversation, for opening it with that source's tool,
and an excerpt: about 160 characters around the first match on one line, cut at
word edges with "…", matched ignoring case and accents.

## Tested

The rules are tested with no store opened — excerpts, people, merging, a whole
search over stand-in sources, the mail rules — on invented names and messages:
15 tests, and every rule broken on purpose is caught (11 of 11 mutations).
Checked by hand on a real Mac (read-only, nothing recorded): all four sources
readable, a common word found across them, an unknown name skipped with its
reasons.

## Requirements

macOS 14 or later; Swift 6.2. Reading Messages and Mail needs Full Disk Access
for the app that runs it; names need Contacts access.

## License

MIT — see [LICENSE](LICENSE).
