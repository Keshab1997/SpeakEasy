# 🎯 Mock Test Content Guide
### SpeakEasy — 70টি Mock Test-এর জন্য প্রশ্ন কন্টেন্ট গাইড

---

## 📖 কিভাবে এই ফাইল ব্যবহার করবেন

1. **প্রথমে** নিচে আপনার টেস্টের টপিক দেখুন
2. **তারপর** সংশ্লিষ্ট `mock_test_XX.json` ফাইলটি খুলুন
3. **সেখানে** ২০টি করে প্রশ্ন বসান
4. **প্রতিটি প্রশ্নের জন্য** → question, 4টি options, correctIndex, explanation দিন

---

## 🏗️ JSON স্ট্রাকচার (প্রত্যেক ফাইলের ফরম্যাট)

```json
{
  "id": "mock_test_01",
  "testNumber": 1,
  "title": "Mock Test 1",
  "description": "Articles (a/an/the) — Basic English Grammar",
  "questions": [
    {
      "question": "আপনার প্রশ্ন এখানে লিখুন?",
      "options": [
        "সঠিক উত্তরটি",
        "ভুল অপশন ১",
        "ভুল অপশন ২",
        "ভুল অপশন ৩"
      ],
      "correctIndex": 0,
      "explanation": "কেন এই উত্তরটি সঠিক তা বুঝিয়ে বলুন"
    }
  ]
}
```

> ⚠️ **মনে রাখবেন:** `correctIndex` সবসময় 0 থেকে 3 এর মধ্যে হবে। 0 = প্রথম অপশন, 1 = দ্বিতীয় অপশন, ইত্যাদি।

---

## 🧪 ২০টি প্রশ্নের ভাগ (প্রত্যেক টেস্টের জন্য)

| ধরন | কয়টি | বর্ণনা |
|------|-------|--------|
| **Direct Knowledge** | ৮টি | সরাসরি নিয়ম জানতে চাওয়া (যেমন: "He ___ a student" → is) |
| **Error Detection** | ৪টি | ভুল বাক্য শনাক্ত করা |
| **Fill in the Blanks** | ৪টি | শূন্যস্থান পূরণ |
| **Bangla → English** | ২টি | বাংলা বাক্যের ইংরেজি অনুবাদ বেছে নেওয়া |
| **Meaning / Vocabulary** | ২টি | শব্দের অর্থ বা ব্যবহার |

---

## 📋 টেস্টওয়াইজ টপিক ও কন্টেন্ট গাইড

---

### 🟢 LEVEL 1: Beginner Foundation (Test 01–20)

---

#### Test 01: Articles (a/an/the)

**কেমন প্রশ্ন হবে:**
- কখন `a` ব্যবহার করবে আর কখন `an`?
- কোথায় `the` বসে আর কোথায় বসে না?
- Common mistakes: "He is ___ teacher." → a/an/the/ no article

**উদাহরণ প্রশ্ন:**
> **Q:** She is ___ honest woman.  
> **Options:** ["a", "an", "the", "no article"]  
> **Correct:** 1 (an)  
> **Explanation:** 'Honest' এ 'h' silent, তাই vowel sound এর জন্য 'an' হবে।

---

#### Test 02: This/That/These/Those

**কেমন প্রশ্ন হবে:**
- কাছে vs দূরে বুঝাতে কোনটি ব্যবহার করবে?
- Singular vs Plural এর জন্য কোনটি?
- Is this vs Are these

**উদাহরণ প্রশ্ন:**
> **Q:** ___ are my books over there on the table.  
> **Options:** ["This", "That", "These", "Those"]  
> **Correct:** 3 (Those)  
> **Explanation:** 'Over there' দূরে বোঝাচ্ছে এবং 'books' plural, তাই 'Those' হবে।

---

#### Test 03: Subject + Verb + Object (Basic Sentence Structure)

**কেমন প্রশ্ন হবে:**
- বাক্যের সঠিক ক্রম কোনটি?
- Subject, Verb, Object চেনা
- "I eat rice" — এখানে কোনটি Subject?

**উদাহরণ প্রশ্ন:**
> **Q:** Which sentence is correct?  
> **Options:** [
>   "Rice I eat every day",
>   "I eat rice every day",
>   "Every day rice I eat",
>   "I rice eat every day"
> ]  
> **Correct:** 1  
> **Explanation:** ইংরেজিতে বাক্যের গঠন হয় Subject + Verb + Object + Extra.

---

#### Test 04: Present Indefinite Tense

**কেমন প্রশ্ন হবে:**
- Subject + V1 (+ s/es)
- He/She/It → verb এর সাথে s/es যোগ
- Do/Does দিয়ে প্রশ্ন ও negative

**উদাহরণ প্রশ্ন:**
> **Q:** He ___ to school every day.  
> **Options:** ["go", "goes", "going", "gone"]  
> **Correct:** 1 (goes)  
> **Explanation:** He (3rd person singular) হওয়ায় go → goes হবে।

---

#### Test 05: Present Continuous Tense

**কেমন প্রশ্ন হবে:**
- am/is/are + V+ing
- এখন ঘটছে এমন কাজ বুঝাতে
- "Look! He ___ running."

**উদাহরণ প্রশ্ন:**
> **Q:** They ___ football right now.  
> **Options:** ["play", "plays", "are playing", "is playing"]  
> **Correct:** 2 (are playing)  
> **Explanation:** 'Right now' বর্তমান চলমান কাজ বুঝাচ্ছে। They plural, so 'are playing'।

---

#### Test 06: Present Perfect Tense

**কেমন প্রশ্ন হবে:**
- have/has + V3
- Recently completed বা experience বুঝাতে
- "I have never ___ to London."

**উদাহরণ প্রশ্ন:**
> **Q:** I have already ___ my homework.  
> **Options:** ["do", "did", "done", "doing"]  
> **Correct:** 2 (done)  
> **Explanation:** Present Perfect = have/has + V3 (done)।

---

#### Test 07: Past Indefinite Tense

**কেমন প্রশ্ন হবে:**
- Subject + V2
- Did দিয়ে প্রশ্ন
- "Yesterday I ___ him."

**উদাহরণ প্রশ্ন:**
> **Q:** She ___ a beautiful dress yesterday.  
> **Options:** ["wear", "wears", "wore", "wearing"]  
> **Correct:** 2 (wore)  
> **Explanation:** 'Yesterday' অতীত নির্দেশ করছে, তাই Past Indefinite → V2 (wore)।

---

#### Test 08: Past Continuous + Past Perfect

**কেমন প্রশ্ন হবে:**
- was/were + V+ing vs had + V3
- দুই কাজের আগে-পরে বুঝাতে
- "When I arrived, she ___ (leave)."

**উদাহরণ প্রশ্ন:**
> **Q:** When I called him, he ___ dinner.  
> **Options:** ["has", "had", "was having", "is having"]  
> **Correct:** 2 (was having)  
> **Explanation:** Phone call এর সময় dinner চালু ছিল, তাই Past Continuous।

---

#### Test 09: Future Indefinite (will + V1)

**কেমন প্রশ্ন হবে:**
- will + V1
- ভবিষ্যৎ অভ্যাস, প্রতিশ্রুতি
- "I ___ you tomorrow."

**উদাহরণ প্রশ্ন:**
> **Q:** Don't worry, I ___ you with the work.  
> **Options:** ["help", "helps", "will help", "am helping"]  
> **Correct:** 2 (will help)  
> **Explanation:** প্রতিশ্রুতি বুঝাতে Future Indefinite → will + V1।

---

#### Test 10: Future Continuous + Future Perfect

**কেমন প্রশ্ন হবে:**
- will be + V+ing vs will have + V3
- "By next year, I ___ (graduate)."
- "This time tomorrow, I ___ (fly) to Dhaka."

**উদাহরণ প্রশ্ন:**
> **Q:** By 2028, I ___ my university degree.  
> **Options:** ["complete", "will complete", "will be completing", "will have completed"]  
> **Correct:** 3 (will have completed)  
> **Explanation:** 'By 2028' একটি নির্দিষ্ট সময়ের আগে শেষ হবে, তাই Future Perfect।

---

#### Test 11: Am/Is/Are (To be)

**কেমন প্রশ্ন হবে:**
- I am, He/She/It is, We/You/They are
- "They ___ happy."
- Negative: am not/is not/are not
- Question: Am I? / Is he? / Are you?

**উদাহরণ প্রশ্ন:**
> **Q:** The children ___ very tired after the game.  
> **Options:** ["am", "is", "are", "be"]  
> **Correct:** 2 (are)  
> **Explanation:** Children = plural, so 'are' হবে।

---

#### Test 12: Was/Were (Past of To be)

**কেমন প্রশ্ন হবে:**
- I/He/She/It → was
- We/You/They → were
- "I ___ sick yesterday."

**উদাহরণ প্রশ্ন:**
> **Q:** Where ___ you last night?  
> **Options:** ["was", "were", "am", "is"]  
> **Correct:** 1 (were)  
> **Explanation:** 'You' এর সাথে past tense এ 'were' হয়।

---

#### Test 13: Do/Does/Did

**কেমন প্রশ্ন হবে:**
- Present: Do (I/you/we/they), Does (he/she/it)
- Past: Did (সবার জন্য)
- "___ she like coffee?"

**উদাহরণ প্রশ্ন:**
> **Q:** ___ he play cricket every weekend?  
> **Options:** ["Do", "Does", "Did", "Is"]  
> **Correct:** 1 (Does)  
> **Explanation:** He (3rd person singular) present tense → Does।

---

#### Test 14: Has/Have/Had

**কেমন প্রশ্ন হবে:**
- Have (I/you/we/they), Has (he/she/it)
- Had (past, সবার জন্য)
- Possession, obligation বোঝাতে
- "She ___ a new car."

**উদাহরণ প্রশ্ন:**
> **Q:** My brother ___ two pet dogs.  
> **Options:** ["have", "has", "had", "having"]  
> **Correct:** 1 (has)  
> **Explanation:** My brother = 3rd person singular present → has।

---

#### Test 15: Can/Cannot (Ability)

**কেমন প্রশ্ন হবে:**
- Can = পারে
- Cannot/Can't = পারে না
- "I ___ swim very well."
- Can I? = কি আমি পারি?

**উদাহরণ প্রশ্ন:**
> **Q:** She is only two years old. She ___ read.  
> **Options:** ["can", "cannot", "could", "will"]  
> **Correct:** 1 (cannot)  
> **Explanation:** ২ বছরের শিশু পড়তে পারে না, তাই cannot (can't)।

---

#### Test 16: Preposition of Place (in, on, at, under, behind, etc.)

**কেমন প্রশ্ন হবে:**
- in = ভিতরে (in the room)
- on = উপরে (on the table)
- at = নির্দিষ্ট জায়গায় (at the door)
- under = নিচে, behind = পিছনে

**উদাহরণ প্রশ্ন:**
> **Q:** The cat is sleeping ___ the bed.  
> **Options:** ["in", "on", "under", "at"]  
> **Correct:** 2 (under)  
> **Explanation:** বিছানার নিচে থাকলে 'under' হয়।

---

#### Test 17: Preposition of Time (in, on, at, since, for)

**কেমন প্রশ্ন হবে:**
- at = নির্দিষ্ট সময়ে (at 5 PM)
- on = দিনে/তারিখে (on Monday)
- in = মাসে/বছরে/সকালে (in July)
- since = থেকে (since 2020)
- for = ধরে (for 2 hours)

**উদাহরণ প্রশ্ন:**
> **Q:** I have been learning English ___ three years.  
> **Options:** ["since", "for", "from", "at"]  
> **Correct:** 1 (for)  
> **Explanation:** 'Three years' একটি সময়কাল, তাই 'for' হবে।

---

#### Test 18: Conjunctions (and, but, or, because, so)

**কেমন প্রশ্ন হবে:**
- and = এবং
- but = কিন্তু
- or = বা
- because = কারণ
- so = তাই

**উদাহরণ প্রশ্ন:**
> **Q:** I was tired, ___ I went to bed early.  
> **Options:** ["and", "but", "or", "so"]  
> **Correct:** 3 (so)  
> **Explanation:** ক্লান্ত → তাই তাড়াতাড়ি ঘুমাতে গেলাম। 'So' = তাই।

---

#### Test 19: Countable vs Uncountable Nouns

**কেমন প্রশ্ন হবে:**
- many + countable (many books)
- much + uncountable (much water)
- few + countable (few people)
- little + uncountable (little time)
- a lot of = উভয়ের সাথে

**উদাহরণ প্রশ্ন:**
> **Q:** How ___ sugar do you want in your tea?  
> **Options:** ["many", "much", "few", "more"]  
> **Correct:** 1 (much)  
> **Explanation:** Sugar uncountable, তাই 'much' হবে।

---

#### Test 20: Beginner Mixed Review

**কেমন প্রশ্ন হবে:**
- Test 01-19 থেকে মিশ্র ২০টি প্রশ্ন
- সব টপিক থেকে সমানভাবে প্রশ্ন দিন
- বাংলা থেকে ইংরেজি অনুবাদ ৪টি প্রশ্ন রাখুন

**উদাহরণ প্রশ্ন:**
> **Q:** কোন বাক্যটি সঠিক?  
> **Options:** [
>   "She don't like tea.",
>   "She doesn't like tea.",
>   "She not like tea.",
>   "She no like tea."
> ]  
> **Correct:** 1  
> **Explanation:** Present Indefinite negative = does not (doesn't) + V1।

---

### 🔵 LEVEL 2: Intermediate Grammar (Test 21–40)

---

#### Test 21: Subject-Verb Agreement

**মূল নিয়ম:** Subject singular হলে verb singular, subject plural হলে verb plural।
- "The boy plays" vs "The boys play"
- "Either the boys or the girl ___ (is/are)"
- "The team ___ (is/are) winning" — collective noun

**উদাহরণ প্রশ্ন:**
> **Q:** The price of these books ___ very high.  
> **Options:** ["is", "are", "were", "have"]  
> **Correct:** 0 (is)  
> **Explanation:** Subject = "The price" (singular), 'of these books' prepositional phrase, মূল verb 'is' হবে।

---

#### Test 22: Singular vs Plural

**মূল নিয়ম:** Singular noun → Plural এ রূপান্তর
- Regular: book → books
- Irregular: child → children, man → men, foot → feet
- fish/sheep/deer → একই থাকে

**উদাহরণ প্রশ্ন:**
> **Q:** I saw two ___ in the forest.  
> **Options:** ["deer", "deers", "deeres", "deer's"]  
> **Correct:** 0 (deer)  
> **Explanation:** Deer এর singular ও plural same।

---

#### Test 23: Personal Pronouns (I, me, my, mine)

**মূল নিয়ম:**
- Subject: I, you, he, she, it, we, they
- Object: me, you, him, her, it, us, them
- Possessive Adj: my, your, his, her, its, our, their
- Possessive Pronoun: mine, yours, his, hers, its, ours, theirs

**উদাহরণ প্রশ্ন:**
> **Q:** This book is ___, not yours.  
> **Options:** ["my", "mine", "me", "I"]  
> **Correct:** 1 (mine)  
> **Explanation:** 'My' এর পরে noun লাগে, কিন্তু এখানে noun নেই, তাই Possessive Pronoun 'mine'।

---

#### Test 24: Adjectives (Comparative & Superlative)

**মূল নিয়ম:**
- Positive: tall → Comparative: taller → Superlative: tallest
- ২+syllable: beautiful → more beautiful → most beautiful
- Irregular: good → better → best, bad → worse → worst

**উদাহরণ প্রশ্ন:**
> **Q:** This is ___ movie I have ever seen.  
> **Options:** ["good", "better", "best", "the best"]  
> **Correct:** 3 (the best)  
> **Explanation:** Superlative এর আগে 'the' বসে। 'ever seen' = সারাজীবনে দেখা, তাই Superlative।

---

#### Test 25: Adverbs (quickly, always, never, etc.)

**মূল নিয়ম:**
- Adverb of Manner (কিভাবে): quickly, slowly, carefully
- Adverb of Frequency (কতবার): always, never, sometimes, usually
- Adverb of Time (কখন): now, then, yesterday
- Adjective + ly = Adverb (quick → quickly)

**উদাহরণ প্রশ্ন:**
> **Q:** She sings ___ . Everyone loves her voice.  
> **Options:** ["beautiful", "beautifully", "more beautiful", "most beautiful"]  
> **Correct:** 1 (beautifully)  
> **Explanation:** 'Sings' verb কে modify করছে, তাই adverb 'beautifully' হবে।

---

#### Test 26: Question Tags

**মূল নিয়ম:**
- Affirmative sentence → Negative tag: "You are coming, aren't you?"
- Negative sentence → Affirmative tag: "You aren't coming, are you?"
- Special: I am → aren't I? / Let's → shall we?

**উদাহরণ প্রশ্ন:**
> **Q:** She doesn't like coffee, ___ ?  
> **Options:** ["does she", "doesn't she", "is she", "isn't she"]  
> **Correct:** 0 (does she)  
> **Explanation:** Sentence negative (doesn't), তাই tag affirmative (does she) হবে।

---

#### Test 27: Wh-Questions

**মূল নিয়ম:**
- What (কী), Where (কোথায়), When (কখন), Why (কেন)
- Who (কে), Whom (কাকে), Whose (কার), Which (কোনটি)
- How (কিভাবে), How many/much (কত)

**উদাহরণ প্রশ্ন:**
> **Q:** ___ does the bus arrive? — At 5 PM.  
> **Options:** ["What", "Where", "When", "Why"]  
> **Correct:** 2 (When)  
> **Explanation:** উত্তর 'At 5 PM' সময় নির্দেশ করছে, তাই 'When' হবে।

---

#### Test 28: Active vs Passive Voice

**মূল নিয়ম:**
- Active: Subject + Verb + Object → "I write a letter"
- Passive: Object + be + V3 + by Subject → "A letter is written by me"
- Tense অনুযায়ী be এর রূপ বদলায়

**উদাহরণ প্রশ্ন:**
> **Q:** The letter ___ by her yesterday.  
> **Options:** ["wrote", "was written", "is written", "has written"]  
> **Correct:** 1 (was written)  
> **Explanation:** 'Yesterday' = past, Passive = was/were + V3।

---

#### Test 29: Modal Verbs (must, should, may, might)

**মূল নিয়ম:**
- Must = অবশ্যই (necessity/obligation)
- Should = উচিত (advice)
- May = হতে পারে (permission/possibility)
- Might = খুবই সামান্য সম্ভাবনা

**উদাহরণ প্রশ্ন:**
> **Q:** You ___ see a doctor. You look very sick.  
> **Options:** ["can", "may", "should", "might"]  
> **Correct:** 2 (should)  
> **Explanation:** অসুস্থ ব্যক্তিকে doctor দেখানোর পরামর্শ দেওয়া হচ্ছে, তাই 'should' (উচিত)।

---

#### Test 30: Would/Could/Shall

**মূল নিয়ম:**
- Would = polite request/desire ("Would you like...?")
- Could = polite request/past ability ("Could you help me?")
- Shall = suggestion (I/We এর সাথে, "Shall we go?")

**উদাহরণ প্রশ্ন:**
> **Q:** ___ you please open the window?  
> **Options:** ["Will", "Would", "Shall", "Must"]  
> **Correct:** 1 (Would)  
> **Explanation:** 'Please' সহ polite request এর জন্য 'Would' সবচেয়ে suitable।

---

#### Test 31: There is/There are

**মূল নিয়ম:**
- There is + singular noun: "There is a book."
- There are + plural noun: "There are many books."
- There is + uncountable: "There is some water."

**উদাহরণ প্রশ্ন:**
> **Q:** ___ a beautiful garden in front of our house.  
> **Options:** ["There is", "There are", "It is", "They are"]  
> **Correct:** 0 (There is)  
> **Explanation:** 'A garden' singular, তাই 'There is' হবে।

---

#### Test 32: Some/Any/No/None

**মূল নিয়ম:**
- Some = affirmative sentences এ ("I have some books.")
- Any = negative/questions এ ("Do you have any books?")
- No = zero quantity ("There is no water.")
- None = zero ("How many? — None.")

**উদাহরণ প্রশ্ন:**
> **Q:** I don't have ___ money with me right now.  
> **Options:** ["some", "any", "no", "none"]  
> **Correct:** 1 (any)  
> **Explanation:** Negative sentence (don't have) → 'any' হবে।

---

#### Test 33: Either/Neither/Both

**মূল নিয়ম:**
- Both = দুইটিই ("Both are correct.")
- Either = দুটির যেকোনো একটি ("Either is fine.")
- Neither = দুটির কোনোটিই নয় ("Neither is correct.")

**উদাহরণ প্রশ্ন:**
> **Q:** You can take ___ the red shirt or the blue one.  
> **Options:** ["both", "either", "neither", "none"]  
> **Correct:** 1 (either)  
> **Explanation:** দুটোর মধ্যে যেকোনো একটি বেছে নেওয়ার সুযোগ, তাই 'either...or'।

---

#### Test 34: If-Clauses (Conditional 1 & 2)

**মূল নিয়ম:**
- Type 1 (Real): If + Present Simple, will + V1
  - "If it rains, I will stay home."
- Type 2 (Unreal): If + Past Simple, would + V1
  - "If I were rich, I would travel."

**উদাহরণ প্রশ্ন:**
> **Q:** If I ___ you, I would accept the offer.  
> **Options:** ["am", "was", "were", "will be"]  
> **Correct:** 2 (were)  
> **Explanation:** Conditional Type 2 এ 'If I were you' একটি fixed expression।

---

#### Test 35: Conditional 3 (If + had + V3, would have + V3)

**মূল নিয়ম:**
- অতীতের অসম্ভব/sh虚幻 কল্পনা
- "If I had studied, I would have passed."
- "If I had known, I would have come."

**উদাহরণ প্রশ্ন:**
> **Q:** If I had known your number, I ___ you.  
> **Options:** ["called", "would call", "would have called", "will call"]  
> **Correct:** 2 (would have called)  
> **Explanation:** Conditional 3: If + had + V3 → would have + V3।

---

#### Test 36: Direct Speech

**মূল নিয়ম:**
- বক্তার কথা হুবহু quotation marks-এ ("...")
- Reporting verb: said, told, asked
- "He said, 'I am busy.'"

**উদাহরণ প্রশ্ন:**
> **Q:** Which sentence uses correct direct speech?  
> **Options:** [
>   "He said I am busy.",
>   "He said, 'I am busy'",
>   "He said 'I am busy'.",
>   "He said, 'I am busy.'"
> ]  
> **Correct:** 3  
> **Explanation:** Comma + quotation marks + period inside quotes = correct direct speech.

---

#### Test 37: Indirect Speech (Reported Speech)

**মূল নিয়ম:**
- Tense backshift: Present → Past, Will → Would, etc.
- Pronoun change: I → he/she, my → his/her
- "He said that he was busy."

**উদাহরণ প্রশ্ন:**
> **Q:** She said, "I love this city." → Indirect speech?  
> **Options:** [
>   "She said that she loved that city.",
>   "She said that I love this city.",
>   "She said that she loves this city.",
>   "She says that she loved that city."
> ]  
> **Correct:** 0  
> **Explanation:** love → loved, this → that, I → she, এবং 'that' যুক্ত হয়েছে।

---

#### Test 38: Relative Clauses (who, which, that)

**মূল নিয়ম:**
- Who = person (The man who came...)
- Which = thing/animal (The book which I read...)
- That = person/thing উভয়ের জন্য (The car that I bought...)
- Whose = possession (The girl whose bag...)

**উদাহরণ প্রশ্ন:**
> **Q:** The woman ___ lives next door is a doctor.  
> **Options:** ["which", "who", "whom", "whose"]  
> **Correct:** 1 (who)  
> **Explanation:** Person (woman) সম্পর্কে বলছি subject হিসেবে, তাই 'who'।

---

#### Test 39: Gerund vs Infinitive

**মূল নিয়ম:**
- Gerund = V+ing (subject/minu হিসেবে): "Swimming is fun."
- Infinitive = to + V1: "I want to swim."
- কিছু verb: enjoy + Ving, decide + to V1
- Stop + Ving vs Stop + to V1 (অর্থ বদলায়)

**উদাহরণ প্রশ্ন:**
> **Q:** I enjoy ___ new people.  
> **Options:** ["meet", "to meet", "meeting", "met"]  
> **Correct:** 2 (meeting)  
> **Explanation:** 'Enjoy' verb এর পরে Gerund (V+ing) হয়।

---

#### Test 40: Intermediate Mixed Review

**কেমন প্রশ্ন হবে:**
- Test 21-39 থেকে মিশ্র ২০টি প্রশ্ন
- Error detection, transformation, fill in the blanks
- কিছু বাংলা থেকে ইংরেজি অনুবাদ

**উদাহরণ প্রশ্ন:**
> **Q:** Find the error: "She don't like the food here."  
> **Options:** [
>   "She",
>   "don't",
>   "like",
>   "the food"
> ]  
> **Correct:** 1 (don't)  
> **Explanation:** She (3rd person) এর সাথে 'doesn't' হবে, 'don't' নয়।

---

### 🟣 LEVEL 3: Advanced Grammar & Speaking (Test 41–55)

---

#### Test 41: Phrasal Verbs (Set 1)

**মূল নিয়ম:** Phrasal Verb = Verb + Preposition/Adverb (অর্থ বদলে যায়)
- give up = ছেড়ে দেওয়া
- look after = যত্ন নেওয়া
- turn on/off = চালু/বন্ধ করা
- put on = পরা
- take off = খুলে ফেলা

**উদাহরণ প্রশ্ন:**
> **Q:** Please ___ the lights when you leave the room.  
> **Options:** ["turn on", "turn off", "turn up", "turn down"]  
> **Correct:** 1 (turn off)  
> **Explanation:** রুম ছেড়ে যাওয়ার সময় lights বন্ধ করতে হবে, তাই 'turn off'।

---

#### Test 42: Phrasal Verbs (Set 2)

**মূল নিয়ম:**
- run out of = ফুরিয়ে যাওয়া
- put off = পিছিয়ে দেওয়া
- break down = ভেঙে পড়া (গাড়ি/মেশিন)
- look forward to = অপেক্ষা করা (উত্তেজনার সাথে)
- come across = হঠাৎ দেখা পাওয়া

**উদাহরণ প্রশ্ন:**
> **Q:** We have ___ milk. I need to buy some.  
> **Options:** ["run out", "run out of", "run after", "run into"]  
> **Correct:** 1 (run out of)  
> **Explanation:** দুধ ফুরিয়ে গেছে বুঝাতে 'run out of' হবে।

---

#### Test 43: Collocations (স্বাভাবিক শব্দ জোড়া)

**মূল নিয়ম:**
- make + noun: make a decision, make a mistake
- do + noun: do homework, do business
- take + noun: take a break, take a shower
- have + noun: have breakfast, have fun

**উদাহরণ প্রশ্ন:**
> **Q:** I need to ___ a decision by tomorrow.  
> **Options:** ["do", "make", "take", "have"]  
> **Correct:** 1 (make)  
> **Explanation:** 'Make a decision' একটি fixed collocation।

---

#### Test 44: Idioms (Set 1)

**মূল নিয়ম:** Idiom = phrase যার আভিধানিক অর্থ থেকে আলাদা অর্থ আছে
- Piece of cake = খুব সহজ
- Break a leg = শুভ কামনা
- Hit the nail on the head = ঠিক বলা
- Once in a blue moon = খুব কমই

**উদাহরণ প্রশ্ন:**
> **Q:** The exam was a ___ . I finished it in 10 minutes.  
> **Options:** ["piece of cake", "hard nut", "long story", "wild goose"]  
> **Correct:** 0 (piece of cake)  
> **Explanation:** 'Piece of cake' = very easy। ১০ মিনিটে শেষ, মানে খুব সহজ ছিল।

---

#### Test 45: Idioms (Set 2)

**মূল নিয়ম:**
- Let the cat out of the bag = গোপন ফাঁস করা
- Burn the midnight oil = রাত জেগে পড়া/কাজ করা
- Cost an arm and a leg = খুব দামি
- Under the weather = অসুস্থ

**উদাহরণ প্রশ্ন:**
> **Q:** She ___ and told everyone about the surprise party.  
> **Options:** ["let the cat out of the bag", "burned the midnight oil", "cost an arm and a leg", "felt under the weather"]  
> **Correct:** 0  
> **Explanation:** সারপ্রাইজ পার্টির কথা বলে দেওয়া = গোপন ফাঁস করা = 'let the cat out of the bag'।

---

#### Test 46: Formal vs Informal English

**মূল নিয়ম:**
- Informal: "I'll give you the info."
- Formal: "I will provide you with the information."
- Informal: "Can you help me?"
- Formal: "Could you kindly assist me?"

**উদাহরণ প্রশ্ন:**
> **Q:** Which is more formal?  
> **Options:** [
>   "Please let me know.",
>   "Please inform me.",
>   "Tell me.",
>   "Keep me posted."
> ]  
> **Correct:** 1 (Please inform me.)  
> **Explanation:** 'Inform' = 'tell' এর চেয়ে বেশি formal। 'Please inform me' সবচেয়ে formal।

---

#### Test 47: Common Grammar Mistakes

**মূল নিয়ম:**
- Your vs You're
- Its vs It's
- There vs Their vs They're
- Then vs Than
- Affect vs Effect

**উদাহরণ প্রশ্ন:**
> **Q:** ___ going to love this movie!  
> **Options:** ["Your", "You're", "Yours", "Your're"]  
> **Correct:** 1 (You're)  
> **Explanation:** 'You are' এর contraction = You're। 'Your' = possessive।

---

#### Test 48: Confusing Words

**মূল নিয়ম:**
- Borrow vs Lend
- Accept vs Except
- Principal vs Principle
- Stationary vs Stationery
- Complement vs Compliment

**উদাহরণ প্রশ্ন:**
> **Q:** Can I ___ your pen for a moment?  
> **Options:** ["borrow", "lend", "take", "give"]  
> **Correct:** 0 (borrow)  
> **Explanation:** 'Borrow' = নিজে নেওয়া (কারো কাছ থেকে), 'Lend' = অন্যকে দেওয়া।

---

#### Test 49: Punctuation & Capitalization

**মূল নিয়ম:**
- Sentence শুরু Capital letter
- Proper noun Capital (Bangladesh, Monday, John)
- Period (.), Comma (,), Question Mark (?), Exclamation (!)
- Apostrophe (') = possession/contraction

**উদাহরণ প্রশ্ন:**
> **Q:** Which sentence is correctly punctuated?  
> **Options:** [
>   "i live in dhaka.",
>   "I live in Dhaka.",
>   "I live in dhaka.",
>   "i live in Dhaka."
> ]  
> **Correct:** 1  
> **Explanation:** "I" সবসময় capital, আর "Dhaka" proper noun capital letter দিয়ে শুরু।

---

#### Test 50: Sentence Transformation

**মূল নিয়ম:**
- Active ↔ Passive
- Direct ↔ Indirect
- Affirmative ↔ Negative
- Simple ↔ Complex
- Positive ↔ Comparative ↔ Superlative

**উদাহরণ প্রশ্ন:**
> **Q:** "He wrote a letter." → Passive form?  
> **Options:** [
>   "A letter is written by him.",
>   "A letter was written by him.",
>   "A letter has been written by him.",
>   "A letter was being written by him."
> ]  
> **Correct:** 1  
> **Explanation:** Active Past Indefinite → Passive Past Indefinite (was + V3)।

---

#### Test 51: Advanced Modals (needn't, used to, ought to)

**মূল নিয়ম:**
- Needn't = প্রয়োজন নেই ("You needn't worry.")
- Used to = আগে করতাম ("I used to smoke.")
- Ought to = উচিত (should এর মতো)
- Dare = সাহস করা

**উদাহরণ প্রশ্ন:**
> **Q:** You ___ have told me earlier. I could have helped.  
> **Options:** ["should", "ought", "used to", "needn't"]  
> **Correct:** 0 (should)  
> **Explanation:** 'Should have + V3' = earlier এ করা উচিত ছিল কিন্তু করিনি।

---

#### Test 52: Causative Verbs (have/get something done)

**মূল নিয়ম:**
- Have/get + object + V3 = অন্যকে দিয়ে করানো
- "I had my hair cut." = আমি চুল কাটিয়েছি।
- "I got my car repaired." = আমি গাড়ি মেরামত করিয়েছি।

**উদাহরণ প্রশ্ন:**
> **Q:** I need to ___ my phone ___.  
> **Options:** ["have / repair", "have / repaired", "have / repairing", "has / repaired"]  
> **Correct:** 1 (have / repaired)  
> **Explanation:** Causative = have + object + V3।

---

#### Test 53: Inversion

**মূল নিয়ম:**
- Negative adverb দিয়ে শুরু হলে inversion:
  - "Never have I seen..."
  - "Not only did he come, but..."
  - "Hardly had I arrived when..."
- Question-formed sentence কিন্তু statement অর্থে

**উদাহরণ প্রশ্ন:**
> **Q:** ___ had I left home when it started raining.  
> **Options:** ["No sooner", "Hardly", "Never", "Not only"]  
> **Correct:** 1 (Hardly)  
> **Explanation:** 'Hardly had I... when' = মাত্রই... তখনই। Inversion structure।

---

#### Test 54: Subjunctive Mood

**মূল নিয়ম:**
- Wish: "I wish I were rich." (was না, সবসময় were)
- If only: "If only I knew."
- Suggest/recommend + that + V1: "I suggest that he go." (goes না)

**উদাহরণ প্রশ্ন:**
> **Q:** I wish I ___ fly like a bird.  
> **Options:** ["can", "could", "will", "would"]  
> **Correct:** 1 (could)  
> **Explanation:** Wish-এ past ability বুঝাতে 'could' হয়।

---

#### Test 55: Advanced Mixed Review

**কেমন প্রশ্ন হবে:**
- Test 41-54 থেকে মিশ্র ২০টি প্রশ্ন
- Phrasal verbs, idioms, collocations বেশি থাকবে
- কিছু error detection + sentence transformation

---

### 🟠 LEVEL 4: Real-Life English (Test 56–70)

---

#### Test 56: Self Introduction

**কেমন প্রশ্ন হবে:**
- নাম, পেশা, শখ, পরিবার নিয়ে প্রশ্ন
- "Hi, let me introduce ___."
- "I work ___ a software engineer."

**উদাহরণ প্রশ্ন:**
> **Q:** "Hi! ___ is my friend, Rahim."  
> **Options:** ["This", "That", "These", "Those"]  
> **Correct:** 0 (This)  
> **Explanation:** কাউকে introduce করার সময় 'This is...' বলা হয়।

---

#### Test 57: Daily Routine

**কেমন প্রশ্ন হবে:**
- প্রতিদিনের কাজ নিয়ে প্রশ্ন
- "I wake ___ at 6 AM."
- "I go ___ bed at 10 PM."
- "___ breakfast, I brush my teeth."

**উদাহরণ প্রশ্ন:**
> **Q:** I usually ___ breakfast at 8 AM.  
> **Options:** ["have", "has", "am having", "had"]  
> **Correct:** 0 (have)  
> **Explanation:** Daily routine বোঝাতে Present Indefinite → have।

---

#### Test 58: At the Restaurant

**কেমন প্রশ্ন হবে:**
- Order দেওয়া, bill চাওয়া, complaint করা
- "I'd like to ___ the menu."
- "Could I ___ the bill, please?"
- "The food is ___ (under cooked/overcooked)."

**উদাহরণ প্রশ্ন:**
> **Q:** "Are you ready to ___?" the waiter asked.  
> **Options:** ["eat", "order", "pay", "leave"]  
> **Correct:** 1 (order)  
> **Explanation:** রেস্টুরেন্টে waiter জিজ্ঞেস করে 'Are you ready to order?'

---

#### Test 59: At the Airport/Hotel

**কেমন প্রশ্ন হবে:**
- চেক-ইন, রিজার্ভেশন, লাগেজ নিয়ে প্রশ্ন
- "I have a reservation ___ the name of..."
- "Could I have a ___ room?"
- "The flight has been ___ (delayed/cancelled)."

**উদাহরণ প্রশ্ন:**
> **Q:** "Could I see your ___ , please?" said the officer.  
> **Options:** ["passport", "ticket", "boarding pass", "ID card"]  
> **Correct:** 2 (boarding pass)  
> **Explanation:** বিমানবন্দরে officer boarding pass চেক করেন।

---

#### Test 60: Telephone Conversations

**কেমন প্রশ্ন হবে:**
- ফোনে কথা বলার এক্সপ্রেশন
- "Can I speak ___ Mr. Khan?"
- "I'm sorry, he's ___ right now."
- "Could you ___ a message?"

**উদাহরণ প্রশ্ন:**
> **Q:** "Hello, ___ is Rahim speaking."  
> **Options:** ["This", "That", "I", "It"]  
> **Correct:** 0 (This)  
> **Explanation:** ফোনে নিজেকে পরিচয় দেওয়ার সময় "This is..." ব্যবহার করা হয়।

---

#### Test 61: Job Interview Questions

**কেমন প্রশ্ন হবে:**
- Interview-এর সাধারণ প্রশ্ন
- "Tell me ___ yourself."
- "What are your ___ and weaknesses?"
- "Why do you want to work ___ ?"

**উদাহরণ প্রশ্ন:**
> **Q:** "What is your greatest ___ ?" the interviewer asked.  
> **Options:** ["strong", "strength", "strongly", "strengthen"]  
> **Correct:** 1 (strength)  
> **Explanation:** 'Greatest' adjective, এর পরে noun 'strength' হবে।

---

#### Test 62: Formal Email Writing

**কেমন প্রশ্ন হবে:**
- ইমেলের শুরু ও শেষ
- "Dear Sir / Madam,"
- "I am writing ___ inquire about..."
- "Yours faithfully / Sincerely"

**উদাহরণ প্রশ্ন:**
> **Q:** How should you start a formal email to someone you don't know?  
> **Options:** [
>   "Hey there,",
>   "Dear Sir or Madam,",
>   "Hello bro,",
>   "Hi,"
> ]  
> **Correct:** 1 (Dear Sir or Madam,)  
> **Explanation:** Unknown recipient → 'Dear Sir or Madam,' সবচেয়ে formal।

---

#### Test 63: Opinion & Discussion

**কেমন প্রশ্ন হবে:**
- মতামত প্রকাশের এক্সপ্রেশন
- "In my ___ , ..."
- "I ___ believe that..."
- "From my ___ of view..."

**উদাহরণ প্রশ্ন:**
> **Q:** "___ my opinion, we should wait."  
> **Options:** ["On", "In", "At", "By"]  
> **Correct:** 1 (In)  
> **Explanation:** 'In my opinion' একটি fixed phrase।

---

#### Test 64: Agreeing & Disagreeing

**কেমন প্রশ্ন হবে:**
- সম্মতি ও অসম্মতি জানানো
- "I ___ with you." (agree)
- "I'm afraid I ___ ." (disagree)
- "You ___ right." (are)

**উদাহরণ প্রশ্ন:**
> **Q:** "I think it's a good idea." — "Yes, I ___ with you."  
> **Options:** ["agree", "disagree", "think", "feel"]  
> **Correct:** 0 (agree)  
> **Explanation:** সম্মতি জানাতে 'I agree with you' বলা হয়।

---

#### Test 65: Apologizing & Thanking

**কেমন প্রশ্ন হবে:**
- দুঃখ প্রকাশ ও ধন্যবাদ জানানো
- "I'm ___ sorry."
- "I ___ your help very much."
- "___ pardon me."

**উদাহরণ প্রশ্ন:**
> **Q:** "Thank you so much!" — "You're ___ !"  
> **Options:** ["welcome", "kind", "good", "nice"]  
> **Correct:** 0 (welcome)  
> **Explanation:** 'Thank you' এর জবাবে 'You're welcome' বলা হয়।

---

#### Test 66: Making Requests & Offers

**কেমন প্রশ্ন হবে:**
- অনুরোধ ও প্রস্তাব
- "Could you please ___ ?"
- "Would you mind ___ ?"
- "Can I ___ you a hand?"

**উদাহরণ প্রশ্ন:**
> **Q:** "Would you mind ___ the window?"  
> **Options:** ["open", "opening", "to open", "opened"]  
> **Correct:** 1 (opening)  
> **Explanation:** 'Would you mind' এর পরে Gerund (V+ing) হয়।

---

#### Test 67: Describing People & Places

**কেমন প্রশ্ন হবে:**
- মানুষ ও জায়গা বর্ণনা
- "He is tall ___ well-built."
- "The city is known ___ its history."
- "She has ___ hair."

**উদাহরণ প্রশ্ন:**
> **Q:** She is ___ . She always helps others.  
> **Options:** ["selfish", "kind-hearted", "lazy", "rude"]  
> **Correct:** 1 (kind-hearted)  
> **Explanation:** 'Always helps others' → kind-hearted (দয়ালু)।

---

#### Test 68: Telling Stories (Past Narrative)

**কেমন প্রশ্ন হবে:**
- গল্প বলার vocabulary
- "First, ___ then, after that, finally"
- "Suddenly, ___ "
- "In the ___ , ..."

**উদাহরণ প্রশ্ন:**
> **Q:** "___ it was raining, we decided to stay home."  
> **Options:** ["Because", "Although", "Since", "Unless"]  
> **Correct:** 0 (Because)  
> **Explanation:** বৃষ্টি হওয়ায় বাসায় থাকার সিদ্ধান্ত → কারণ দেখাতে 'Because'।

---

#### Test 69: Giving Directions

**কেমন প্রশ্ন হবে:**
- দিক নির্দেশনা
- "Go straight, then turn ___ "
- "It's ___ the corner."
- "The bank is ___ the hospital."

**উদাহরণ প্রশ্ন:**
> **Q:** "Go straight and turn ___ at the traffic light."  
> **Options:** ["left", "leave", "lift", "live"]  
> **Correct:** 0 (left)  
> **Explanation:** Direction বোঝাতে 'turn left/right' হয়।

---

#### Test 70: Final Grand Review

**কেমন প্রশ্ন হবে:**
- Level 1-4 সব টপিক থেকে ২০টি প্রশ্ন
- সকল ধরনের প্রশ্ন মিশ্রিত
- Grammar, vocabulary, real-life scenarios সবই থাকবে
- সবচেয়ে চ্যালেঞ্জিং হবে

**উদাহরণ প্রশ্ন:**
> **Q:** "If I ___ harder, I would have passed the test."  
> **Options:** ["study", "studied", "had studied", "would study"]  
> **Correct:** 2 (had studied)  
> **Explanation:** Conditional 3: If + had + V3 → past এর unreal condition।

---

## 📦 Bonus Tips for Writing Good Questions

| # | টিপস |
|---|-------|
| 1 | **প্রশ্ন যেন খুব সহজ না হয়** — ২০/২০ পেতে real effort লাগবে |
| 2 | **প্রতিটি অপশন plausible হতে হবে** — স্পষ্ট ভুল অপশন দেবেন না |
| 3 | **Explanation দিন** — যাতে student শিখতে পারে কেন উত্তরটি সঠিক |
| 4 | **Bangla ব্যবহার করতে পারেন** — question বা explanation-এ বাংলা mix করা যাবে |
| 5 | **বাস্তব উদাহরণ দিন** — "He ___ to school" এর চেয়ে "Rahim ___ to school" better |
| 6 | **বানান ভুল নেই** — সব অপশন spell-check করবেন |
| 7 | **একই প্যাটার্নের সব প্রশ্ন না** — variety রাখুন |

---

## ✅ চেকলিস্ট (একটি টেস্ট写完ের পর)

- [ ] ২০টি প্রশ্ন পূর্ণ হয়েছে?
- [ ] correctIndex 0-3 এর মধ্যে আছে?
- [ ] প্রতিটি প্রশ্নের explanation দেওয়া আছে?
- [ ] Options গুলো realistic এবং বিভ্রান্তিকর?
- [ ] কোনো অপশন duplicate নেই?
- [ ] JSON ফরম্যাট ঠিক আছে? (JSON validator দিয়ে চেক করুন)
- [ ] Bangla ট্রান্সলেশন থাকলে set correctly?

---

> **📌 মনে রাখবেন:** প্রতিটি ফাইলে ২০টি করে প্রশ্ন থাকতে হবে। মোট ৭০টি ফাইল × ২০ = ১৪০০টি প্রশ্ন।  
> কিন্তু চিন্তা নেই — আপনি চাইলে একজন কন্টেন্ট রাইটারকে এই MD ফাইলটি দিয়ে দিতে পারেন, উনি বুঝে ফেলবেন কি করতে হবে! 😊
