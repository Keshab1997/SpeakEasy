#!/usr/bin/env python3
"""Generate mock_test_40 through mock_test_70 with full 20 questions each."""

import json, os

DIR = "assets/json/mock_tests"

def q(question, options, correctIndex, explanation):
    return {"question": question, "options": options, "correctIndex": correctIndex, "explanation": explanation}

ALL = {}

# ===== mock_test_40 - Intermediate Mixed Review =====
ALL["mock_test_40"] = {
    "id": "mock_test_40", "testNumber": 40,
    "title": "Mock Test 40 - Intermediate Mixed Review",
    "description": "Level 2 (Test 21-39) মিশ্র ২০টি প্রশ্ন। Subject-Verb Agreement, Pronouns, Adjectives, Adverbs, Question Tags, Wh-Questions, Voice, Modals, Conditionals, Direct/Indirect Speech, Relative Clauses, Gerund/Infinitive — সব টপিক থেকে।",
    "questions": [
        q("Which sentence has correct subject-verb agreement?", ["The list of items are on the table.", "The list of items is on the table.", "The list of items were on the table.", "The list of items have been on the table."], 1, "Subject = 'The list' (singular), তাই 'is' হবে। 'of items' — prepositional phrase, এটি subject নয়।"),
        q("He is ___ than his brother.", ["tall", "taller", "tallest", "more tall"], 1, "Comparative degree: tall → taller (দুজনের মধ্যে তুলনা)।"),
        q("___ does the train arrive? — At 6 PM.", ["What", "Where", "When", "Why"], 2, "উত্তর 'At 6 PM' সময় নির্দেশ করছে, তাই 'When'।"),
        q("She sings ___. Everyone loves her voice.", ["beautiful", "beautifully", "more beautiful", "most beautiful"], 1, "'Sings' verb কে modify করছে → adverb 'beautifully'।"),
        q("Find the error: 'She don't like coffee.'", ["She", "don't", "like", "coffee"], 1, "She (3rd person) → 'doesn't' হবে, 'don't' নয়।"),
        q("You are coming to the party, ___?", ["are you", "aren't you", "isn't you", "don't you"], 1, "Affirmative sentence → Negative tag। 'You are' → 'aren't you?'"),
        q("This book is ___, not yours.", ["my", "mine", "me", "I"], 1, "Possessive Pronoun (noun ছাড়া) → 'mine'। 'my' এর পরে noun লাগে।"),
        q("The letter ___ by her yesterday.", ["wrote", "was written", "is written", "has written"], 1, "Yesterday → Past, Passive → was/were + V3। 'was written'।"),
        q("You ___ see a doctor. You look very sick.", ["can", "may", "should", "might"], 2, "পরামর্শ → 'should' (উচিত)।"),
        q("If I were you, I ___ the job.", ["accept", "will accept", "would accept", "accepted"], 2, "Type 2 Conditional: If + Past Simple → would + V1।"),
        q("Error Detection: 'There is many books on the table.'", ["There is", "many books", "on the table", "—"], 0, "'Many books' plural, so 'There are' হবে।"),
        q("She said that she ___ the project already.", ["finishes", "finished", "had finished", "has finished"], 2, "Indirect Speech backshift: Present Perfect → Past Perfect। 'had finished'।"),
        q("The woman ___ lives next door is a doctor.", ["which", "who", "whom", "whose"], 1, "Person (woman) → 'who'।"),
        q("I enjoy ___ new people.", ["meet", "to meet", "meeting", "met"], 2, "'Enjoy' verb → Gerund (meeting)।"),
        q("Fill: 'I have never ___ to London.'", ["be", "been", "being", "was"], 1, "Present Perfect: have/has + V3 (been)।"),
        q("Fill: 'There isn't ___ milk in the fridge.'", ["some", "any", "no", "none"], 1, "Negative sentence → 'any'।"),
        q("Fill: 'Neither of the answers ___ correct.'", ["is", "are", "were", "have been"], 0, "'Neither' singular, তাই 'is'।"),
        q("Fill: 'He would have passed if he ___ harder.'", ["studies", "studied", "had studied", "would study"], 2, "Type 3: If + had + V3 → would have + V3। 'had studied'।"),
        q("অনুবাদ: 'সে প্রতিদিন স্কুলে যায়।'", ["He go to school every day.", "He goes to school every day.", "He is going to school every day.", "He went to school every day."], 1, "Present Indefinite (habit): He + V+s (goes)।"),
        q("অনুবাদ: 'আমি যদি পাখি হতাম, তাহলে উড়ে বেড়াতাম।'", ["If I am a bird, I will fly.", "If I were a bird, I would fly.", "If I was a bird, I would fly.", "If I am a bird, I would fly."], 1, "Unreal present → Type 2: If + were, would + V1।")
    ]
}

# ===== mock_test_41 - Phrasal Verbs Set 1 =====
ALL["mock_test_41"] = {
    "id": "mock_test_41", "testNumber": 41,
    "title": "Mock Test 41 - Phrasal Verbs (Set 1)",
    "description": "Phrasal Verbs (Set 1) নিয়ে ২০টি প্রশ্ন। give up, look after, turn on/off, put on, take off, look for, get up, sit down, stand up, come back ইত্যাদি phrasal verbs-এর অর্থ ও ব্যবহার।",
    "questions": [
        q("Phrasal Verb কী?", ["একটি single word verb", "Verb + Preposition/Adverb যা একত্রে ভিন্ন অর্থ দেয়", "শুধু একটি preposition", "একটি noun phrase"], 1, "Phrasal verb = verb + particle যা একত্রে ভিন্ন অর্থ তৈরি করে। যেমন: give up = ছেড়ে দেওয়া।"),
        q("'Give up' phrase-টির অর্থ কী?", ["দেওয়া", "উপরে তোলা", "ছেড়ে দেওয়া / হাল ছেড়ে দেওয়া", "নিচে রাখা"], 2, "'Give up' = quit / stop trying। যেমন: Don't give up on your dreams."),
        q("'Look after' phrase-টির অর্থ কী?", ["খোঁজা", "যত্ন নেওয়া", "দেখা", "অপেক্ষা করা"], 1, "'Look after' = take care of। যেমন: She looks after her younger brother."),
        q("Please ___ the lights when you leave.", ["turn on", "turn off", "turn up", "turn down"], 1, "রুম ছেড়ে যাওয়ার সময় lights বন্ধ করা → 'turn off'।"),
        q("She ___ her coat before going out.", ["put on", "put off", "put up", "put down"], 0, "কোট পরা → 'put on'।"),
        q("When he saw the police, he began ___.", ["run out", "run away", "run after", "run into"], 1, "পুলিশ দেখে পালানো → 'run away'।"),
        q("I need to ___ my keys. I can't find them.", ["look at", "look for", "look after", "look up"], 1, "চাবি খোঁজা → 'look for'।"),
        q("The meeting has been ___ until next week.", ["put on", "put off", "put up", "put down"], 1, "মিটিং পিছিয়ে দেওয়া → 'put off' (postpone)।"),
        q("He ___ very early every morning.", ["gets on", "gets up", "gets off", "gets in"], 1, "সকালে ঘুম থেকে ওঠা → 'get up'।"),
        q("Please ___ and take a seat.", ["sit down", "sit up", "sit in", "sit on"], 0, "বসতে বলা → 'sit down'।"),
        q("Error: 'She turned on the invitation because she was busy.' — ভুল phrasal verb?", ["turned on", "the invitation", "she was busy", "—"], 0, "'Turned on' = চালু করা। এখানে 'turned down' (প্রত্যাখ্যান) হবে।"),
        q("Error: 'He gave up smoking last year.' — বাক্যটি সঠিক?", ["সঠিক", "ভুল, give up smoking হয় না", "গঠন ভুল", "give up-এর পরে Gerund হয় না"], 0, "'Give up' = quit। Give up smoking = ধূমপান ছেড়ে দেওয়া — সঠিক।"),
        q("Error: 'Please put on your shoes before entering the mosque.' — সঠিক?", ["সঠিক", "ভুল, take off হবে", "ভুল, put off হবে", "ভুল, put up হবে"], 1, "মসজিদে প্রবেশের আগে জুতা খুলতে হয় → 'take off'। 'Put on' = পরা — ভুল।"),
        q("Error: 'Look after my bag, please' — 'look after' এর ব্যবহার সঠিক?", ["সঠিক", "ভুল, look for হবে", "ভুল, look at হবে", "ভুল, look up হবে"], 0, "Look after = যত্ন নেওয়া — সঠিক।"),
        q("Fill: 'I am ___ forward to meeting you.'", ["looking", "looking for", "looking after", "looking up"], 0, "'Look forward to' = অপেক্ষা করা (উত্তেজনার সাথে)।"),
        q("Fill: 'She ___ up a new hobby.'", ["took", "turned", "gave", "put"], 0, "'Take up' = শুরু করা (hobby)।"),
        q("Fill: 'Can you ___ me up at 6 AM?'", ["wake", "get", "pick", "call"], 0, "'Wake up' = জাগানো।"),
        q("Fill: 'He ___ out that he had won.'", ["found", "came", "went", "ran"], 0, "'Find out' = জানতে পারা / discover।"),
        q("অনুবাদ: 'দয়া করে আলো জ্বালাও।'", ["Please turn off the light.", "Please turn on the light.", "Please turn up the light.", "Please turn down the light."], 1, "আলো জ্বালানো = 'turn on the light'।"),
        q("অনুবাদ: 'সে তার বাবার যত্ন নেয়।'", ["She looks for her father.", "She looks after her father.", "She looks at her father.", "She looks up her father."], 1, "যত্ন নেওয়া = 'look after'।")
    ]
}

# ===== mock_test_42 - Phrasal Verbs Set 2 =====
ALL["mock_test_42"] = {
    "id": "mock_test_42", "testNumber": 42,
    "title": "Mock Test 42 - Phrasal Verbs (Set 2)",
    "description": "Phrasal Verbs (Set 2) নিয়ে ২০টি প্রশ্ন। run out of, put off, break down, come across, call off, bring up, carry on, find out, give in, turn down ইত্যাদি।",
    "questions": [
        q("'Run out of' phrase-টির অর্থ কী?", ["ছুটে যাওয়া", "ফুরিয়ে যাওয়া", "পড়ে যাওয়া", "ভিতরে যাওয়া"], 1, "'Run out of' = শেষ হয়ে যাওয়া / exhausted। যেমন: We have run out of milk."),
        q("'Put off' phrase-টির অর্থ কী?", ["রাখা", "পরে দেওয়া / পিছিয়ে দেওয়া", "উপরে রাখা", "বন্ধ করা"], 1, "'Put off' = postpone / delay। যেমন: Don't put off your homework."),
        q("'Break down' phrase-টির অর্থ কী?", ["ভেঙে ফেলা", "ভেঙে পড়া (গাড়ি/মেশিন)", "ভিতরে যাওয়া", "উপরে যাওয়া"], 1, "'Break down' = stop working (car, machine) বা emotionally collapse।"),
        q("'Come across' phrase-টির অর্থ কী?", ["পারে আসা", "হঠাৎ দেখা পাওয়া", "পিছনে আসা", "উপরে আসা"], 1, "'Come across' = unexpectedly find/meet। যেমন: I came across an old friend."),
        q("'Call off' phrase-টির অর্থ কী?", ["ডাকা", "বাতিল করা", "উপরে ডাকা", "নিচে ডাকা"], 1, "'Call off' = cancel। যেমন: The match was called off due to rain."),
        q("The car ___ on the highway yesterday.", ["broke down", "broke up", "broke into", "broke out"], 0, "গাড়ি নষ্ট → 'broke down'।"),
        q("I ___ an interesting article in the newspaper.", ["came across", "came after", "came up", "came in"], 0, "আকস্মিকভাবে পাওয়া → 'came across'।"),
        q("The wedding was ___ because of the storm.", ["called up", "called off", "called on", "called in"], 1, "বিয়ে বাতিল → 'called off'।"),
        q("He ___ a very interesting topic during the meeting.", ["brought up", "brought in", "brought out", "brought down"], 0, "আলোচনায় topic তোলা → 'brought up'।"),
        q("Please ___ with your good work.", ["carry on", "carry out", "carry in", "carry up"], 0, "'Carry on' = continue।"),
        q("Error: 'She turned down the job offer.' — সঠিক?", ["সঠিক", "ভুল, turn off হবে", "ভুল, turn up হবে", "ভুল, turn on হবে"], 0, "'Turn down' = reject — সঠিক।"),
        q("Error: 'We need to cut out on expenses.' — ভুল?", ["cut out", "on expenses", "We need to", "—"], 0, "'Cut down on' = কমানো। 'Cut out' = বাদ দেওয়া। 'Cut down on expenses' হবে।"),
        q("Error: 'He dropped out of school at age 16.' — সঠিক?", ["সঠিক", "ভুল, drop off হবে", "ভুল, drop in হবে", "ভুল, drop by হবে"], 0, "'Drop out' = স্কুল ছেড়ে দেওয়া — সঠিক।"),
        q("Error: 'She got along with her new colleagues.' — সঠিক?", ["সঠিক", "ভুল, get on হবে", "ভুল, get over হবে", "ভুল, get through হবে"], 0, "'Get along with' = ভালো সম্পর্ক থাকা — সঠিক।"),
        q("Fill: 'I need to ___ out who broke the window.'", ["find", "look", "point", "work"], 0, "'Find out' = discover / জানতে পারা।"),
        q("Fill: 'She ___ up smoking for her health.'", ["gave", "took", "put", "made"], 0, "'Give up' = quit।"),
        q("Fill: 'The fire ___ out in the middle of the night.'", ["broke", "came", "went", "ran"], 0, "'Break out' = শুরু হওয়া (fire, war, disease)।"),
        q("Fill: 'He ___ out the truth at last.'", ["found", "spoke", "talked", "said"], 0, "'Find out' = জানতে পারা।"),
        q("অনুবাদ: 'দুধ ফুরিয়ে গেছে।'", ["The milk has run out of.", "We have run out of milk.", "The milk has run away.", "The milk has run after."], 1, "'Run out of milk' = দুধ ফুরিয়ে যাওয়া।"),
        q("অনুবাদ: 'সে একটি পুরনো বন্ধুর দেখা পেয়ে গেল।'", ["She came across an old friend.", "She came after an old friend.", "She came up an old friend.", "She came in an old friend."], 0, "'Come across' = হঠাৎ দেখা পাওয়া।")
    ]
}

# ===== mock_test_43 - Collocations =====
ALL["mock_test_43"] = {
    "id": "mock_test_43", "testNumber": 43,
    "title": "Mock Test 43 - Collocations",
    "description": "Collocations (স্বাভাবিক শব্দ জোড়া) নিয়ে ২০টি প্রশ্ন। Make/Do/Take/Have/Catch/Break ইত্যাদি verb-এর সাথে noun-এর সঠিক collocation।",
    "questions": [
        q("Collocation কী?", ["একটি long sentence", "শব্দের স্বাভাবিক জোড়া যা একসাথে ব্যবহৃত হয়", "একটি grammar rule", "একটি punctuation rule"], 1, "Collocation = words that naturally go together। যেমন: make a decision (not 'do a decision')।"),
        q("'Make' verb-টির সাথে কোন noun-টি collocate হয়?", ["homework", "a decision", "a shower", "business"], 1, "'Make a decision' = সিদ্ধান্ত (correct collocation)। Do homework, take a shower, do business।"),
        q("'Do' verb-টির সাথে কোন noun-টি collocate হয়?", ["a mistake", "a decision", "homework", "a promise"], 2, "'Do homework' = বাড়ির কাজ করা।"),
        q("'Take' verb-টির সাথে কোন noun-টি collocate হয়?", ["a decision", "a break", "business", "a promise"], 1, "'Take a break' = বিশ্রাম নেওয়া।"),
        q("'Have' verb-টির সাথে কোন noun-টি collocate হয়?", ["a mistake", "fun", "a decision", "homework"], 1, "'Have fun' = মজা করা।"),
        q("I need to ___ a decision by tomorrow.", ["do", "make", "take", "have"], 1, "'Make a decision' — সঠিক collocation।"),
        q("She ___ a mistake in calculation.", ["did", "made", "took", "had"], 1, "'Make a mistake' — সঠিক collocation।"),
        q("He always ___ his homework on time.", ["makes", "does", "takes", "has"], 1, "'Do homework' — সঠিক collocation।"),
        q("Let's ___ a break for 10 minutes.", ["make", "do", "take", "have"], 2, "'Take a break' — সঠিক collocation।"),
        q("Did you ___ fun at the party?", ["make", "do", "take", "have"], 3, "'Have fun' — সঠিক collocation।"),
        q("Error: 'I need to do a decision.' — ভুল?", ["I need", "to do", "a decision", "—"], 1, "'Make a decision' হবে, 'do a decision' নয়।"),
        q("Error: 'She made her homework quickly.' — ভুল?", ["She made", "her homework", "quickly", "—"], 0, "'Do homework' হবে, 'make homework' নয়।"),
        q("Error: 'Take a shower' — সঠিক?", ["সঠিক", "ভুল, have a shower হবে", "ভুল, make a shower হবে", "ভুল, do a shower হবে"], 0, "'Take a shower' / 'Have a shower' — দুটোই সঠিক।"),
        q("Error: 'He had a promise to keep.' — সঠিক?", ["সঠিক", "ভুল, make a promise হবে", "ভুল, do a promise হবে", "ভুল, take a promise হবে"], 0, "'Make a promise' = প্রতিশ্রুতি দেওয়া। 'Have a promise' = প্রতিশ্রুতি রাখা। দুটোই collocation।"),
        q("Fill: 'She ___ a great job on the presentation.'", ["made", "did", "took", "had"], 1, "'Do a good/great job' = ভালো কাজ করা।"),
        q("Fill: 'I need to ___ a phone call.'", ["make", "do", "take", "have"], 0, "'Make a phone call' = ফোন করা।"),
        q("Fill: 'He ___ attention to the teacher.'", ["made", "did", "paid", "took"], 2, "'Pay attention' = মনোযোগ দেওয়া।"),
        q("Fill: 'She ___ a photograph of the sunset.'", ["made", "did", "took", "had"], 2, "'Take a photograph' = ছবি তোলা।"),
        q("অনুবাদ: 'আমি একটি ভুল করেছি।'", ["I did a mistake.", "I made a mistake.", "I took a mistake.", "I had a mistake."], 1, "'Make a mistake' — সঠিক collocation।"),
        q("অনুবাদ: 'তোমার কি নাস্তা হয়েছে?'", ["Did you make breakfast?", "Did you do breakfast?", "Did you have breakfast?", "Did you take breakfast?"], 2, "'Have breakfast' = নাস্তা করা — সঠিক collocation।")
    ]
}

# ===== mock_test_44 - Idioms Set 1 =====
ALL["mock_test_44"] = {
    "id": "mock_test_44", "testNumber": 44,
    "title": "Mock Test 44 - Idioms (Set 1)",
    "description": "Idioms (Set 1) নিয়ে ২০টি প্রশ্ন। Piece of cake, Break a leg, Hit the nail on the head, Once in a blue moon, Cost an arm and a leg, Under the weather, Let the cat out of the bag ইত্যাদি।",
    "questions": [
        q("'Piece of cake' idiom-টির অর্থ কী?", ["কেকের টুকরো", "খুব সহজ কাজ", "খুব কঠিন কাজ", "মিষ্টি জিনিস"], 1, "'Piece of cake' = very easy। যেমন: The exam was a piece of cake।"),
        q("'Break a leg' idiom-টি কখন ব্যবহার করা হয়?", ["কেউ পা ভাঙলে", "শুভকামনা জানাতে (পারফরম্যান্সের আগে)", "অনুষ্ঠানে", "খেলাধুলায়"], 1, "'Break a leg' = Good luck! (theater/performance-এর আগে)"),
        q("'Hit the nail on the head' idiom-টির অর্থ কী?", ["পেরেক মারা", "ঠিক বলা / সঠিক অনুমান করা", "কাজ শুরু করা", "ঝগড়া করা"], 1, "'Hit the nail on the head' = exactly right।"),
        q("'Once in a blue moon' idiom-টির অর্থ কী?", ["প্রতিদিন", "মাসে একবার", "খুব কমই", "সপ্তাহে একবার"], 2, "'Once in a blue moon' = very rarely / খুবই কম।"),
        q("'Cost an arm and a leg' idiom-টির অর্থ কী?", ["হাত-পা হারানো", "খুব দামি হওয়া", "অপারেশন করা", "সস্তা হওয়া"], 1, "'Cost an arm and a leg' = very expensive।"),
        q("The test was a ___ . I finished in 5 minutes!", ["piece of cake", "hard nut", "long story", "wild goose"], 0, "খুব সহজ → 'piece of cake'।"),
        q("She ___ and told everyone about the surprise.", ["hit the nail", "broke a leg", "let the cat out of the bag", "cost an arm"], 2, "গোপন ফাঁস → 'let the cat out of the bag'।"),
        q("He visits home ___ — maybe once a year.", ["every day", "once in a blue moon", "all the time", "now and then"], 1, "বছরে একবার = খুব কমই → 'once in a blue moon'।"),
        q("I'm feeling ___ . I think I caught a cold.", ["under the weather", "over the moon", "on top of the world", "full of beans"], 0, "অসুস্থ/খারাপ লাগা → 'under the weather'।"),
        q("You ___! You got the highest score!", ["broke a leg", "hit the nail", "missed the point", "spilled the beans"], 0, "'Break a leg!' = শুভকামনা/অভিনন্দন।"),
        q("Error: 'The exam was a piece of cake, so I struggled a lot.' — সমস্যা?", ["piece of cake সঠিক নয়", "'piece of cake' = সহজ, 'struggled' = কঠিন — বিরোধ", "গঠন ভুল", "কোনো সমস্যা নেই"], 1, "অর্থের বিরোধ।"),
        q("Error: 'He hit the nail on the head when he guessed my age wrong.' — ভুল?", ["hit = সঠিক, guessed wrong = ভুল — বিরোধ", "বাক্য ভুল", "—", "—"], 0, "'Hit the nail on the head' = সঠিক বলা, 'guessed wrong' = ভুল — বিরোধ।"),
        q("Error: 'This diamond ring costs an arm and a leg.' — সঠিক?", ["সঠিক", "ভুল", "ভুল, cost arm and leg health-এর জন্য", "—"], 0, "'Cost an arm and a leg' = খুব দামি — হীরার আংটির জন্য সঠিক।"),
        q("Error: 'I see him once in a blue moon' — মানে?", ["প্রতিদিন দেখি", "কখনো দেখি না", "খুব কমই দেখি", "সবসময় দেখি"], 2, "'Once in a blue moon' = very rarely = খুব কমই।"),
        q("Fill: 'Don't worry. It will be a ___ of cake.'", ["piece", "slice", "bit", "part"], 0, "Fixed idiom: 'a piece of cake'।"),
        q("Fill: 'She was ___ the weather, so she stayed home.'", ["under", "over", "on", "in"], 0, "'Under the weather' = অসুস্থ।"),
        q("Fill: 'You ___ the nail on the head with that answer.'", ["hit", "missed", "broke", "cut"], 0, "'Hit the nail on the head' = exactly right।"),
        q("Fill: 'That car costs ___ arm and a leg.'", ["an", "a", "the", "one"], 0, "'Cost an arm and a leg' — 'an' (arm vowel sound দিয়ে শুরু)।"),
        q("অনুবাদ (idiom): 'পরীক্ষাটা খুব সহজ ছিল।'", ["The exam was a hard nut.", "The exam was a piece of cake.", "The exam was a long story.", "The exam was a wild goose chase."], 1, "'A piece of cake' = খুব সহজ।"),
        q("অনুবাদ (idiom): 'সে খুবই কম ইংরেজি বলে।'", ["She speaks English every day.", "She speaks English once in a blue moon.", "She always speaks English.", "She speaks English all the time."], 1, "'Once in a blue moon' = খুব কমই।")
    ]
}

# ===== mock_test_45 - Idioms Set 2 =====
ALL["mock_test_45"] = {
    "id": "mock_test_45", "testNumber": 45,
    "title": "Mock Test 45 - Idioms (Set 2)",
    "description": "Idioms (Set 2) নিয়ে ২০টি প্রশ্ন। Let the cat out of the bag, Burn the midnight oil, When pigs fly, Spill the beans, Hit the sack, Bite the bullet, The ball is in your court, Call it a day ইত্যাদি।",
    "questions": [
        q("'Let the cat out of the bag' অর্থ কী?", ["বেড়াল বের করা", "গোপন ফাঁস করা", "খেলা করা", "কথা বলা"], 1, "'Let the cat out of the bag' = reveal a secret accidentally।"),
        q("'Burn the midnight oil' অর্থ কী?", ["রাতে তেল পোড়ানো", "রাত জেগে পড়া/কাজ করা", "আগুন জ্বালানো", "রান্না করা"], 1, "'Burn the midnight oil' = study/work late into the night।"),
        q("'When pigs fly' অর্থ কী?", ["শূকর উড়লে", "অসম্ভব ঘটনা", "বিরল ঘটনা", "মজার ঘটনা"], 1, "'When pigs fly' = something that will never happen (অসম্ভব)।"),
        q("'Spill the beans' অর্থ কী?", ["বিন ছড়ানো", "গোপন তথ্য ফাঁস করা", "খাবার ফেলা", "পরিষ্কার করা"], 1, "'Spill the beans' = reveal a secret।"),
        q("'Bite the bullet' অর্থ কী?", ["গুলি কামড়ানো", "কঠিন কিছু সাহসের সাথে মোকাবিলা করা", "যুদ্ধ করা", "খেলা করা"], 1, "'Bite the bullet' = face a difficult situation with courage।"),
        q("She ___ and everyone knew about the party.", ["let the cat out", "burned the midnight oil", "bit the bullet", "hit the sack"], 0, "গোপন ফাঁস → 'let the cat out'।"),
        q("He ___ to pass the final exam.", ["let the cat out", "burned the midnight oil", "spilled the beans", "bit the bullet"], 1, "রাত জেগে পড়া → 'burned the midnight oil'।"),
        q("I'll clean my room ___ — meaning never!", ["when pigs fly", "once in a blue moon", "now and then", "every day"], 0, "'When pigs fly' = never।"),
        q("Come on, ___! Tell me what happened.", ["spill the beans", "burn the midnight oil", "hit the sack", "bite the bullet"], 0, "'Spill the beans' = গোপন বলো।"),
        q("I decided to ___ and tell him the truth.", ["bite the bullet", "spill the beans", "let the cat out", "hit the sack"], 0, "সাহস করে সত্য বলা → 'bite the bullet'।"),
        q("Error: 'He burned the midnight oil by sleeping early.' — ভুল?", ["বিরোধ (burn oil = রাত জেগে কাজ, sleeping = তাড়াতাড়ি ঘুম)", "গঠন ভুল", "—", "—"], 0, "'Burn the midnight oil' = রাত জেগে কাজ, 'sleeping early' = তাড়াতাড়ি ঘুম — বিপরীত।"),
        q("Error: 'She let the cat out by keeping the secret.' — ভুল?", ["let out = ফাঁস, keeping = রাখা — বিরোধ", "—", "—", "—"], 0, "'Let the cat out' = গোপন ফাঁস, 'keeping the secret' = গোপন রাখা — বিপরীত।"),
        q("Error: 'I'll do it when pigs fly' — বক্তা কী বোঝাচ্ছেন?", ["শীঘ্রই করবেন", "কখনোই করবেন না", "নিয়মিত করেন", "ইতিমধ্যে করেছেন"], 1, "'When pigs fly' = never / অসম্ভব।"),
        q("Error: 'He spilled the beans and kept the surprise a secret.' — ভুল?", ["spilled = ফাঁস, kept secret = গোপন রাখা — বিরোধ", "—", "—", "—"], 0, "'Spilled the beans' = গোপন ফাঁস → surprise আর secret থাকে না! বিরোধ।"),
        q("Fill: 'She ___ the bullet and told her parents the accident.'", ["bit", "ate", "took", "had"], 0, "'Bite the bullet' — past = bit।"),
        q("Fill: 'Don't ___ the beans! It's a surprise.'", ["spill", "eat", "cook", "drop"], 0, "'Spill the beans' = গোপন ফাঁস করা।"),
        q("Fill: 'I need to ___ the midnight oil tonight.'", ["burn", "light", "fire", "cook"], 0, "'Burn the midnight oil' = রাত জেগে কাজ করা।"),
        q("Fill: 'He'll apologize when ___ fly.'", ["pigs", "birds", "planes", "kites"], 0, "'When pigs fly' = কখনোই না।"),
        q("অনুবাদ: 'সে গোপন কথাটা ফাঁস করে দিয়েছে।'", ["She let the cat out.", "She burned the midnight oil.", "She bit the bullet.", "She hit the sack."], 0, "'Let the cat out' = গোপন ফাঁস।"),
        q("অনুবাদ: 'কঠিন কাজটা সাহসের সাথে মোকাবিলা করলাম।'", ["I let the cat out.", "I burned the midnight oil.", "I bit the bullet.", "I spilled the beans."], 2, "'Bite the bullet' = সাহসের সাথে কঠিন পরিস্থিতি মোকাবিলা।")
    ]
}

# ===== mock_test_46 - Formal vs Informal =====
ALL["mock_test_46"] = {
    "id": "mock_test_46", "testNumber": 46,
    "title": "Mock Test 46 - Formal vs Informal English",
    "description": "Formal ও Informal English-এর পার্থক্য নিয়ে ২০টি প্রশ্ন। কোন context-এ কোন ধরনের language ব্যবহার করতে হয়, formal synonyms, email/letter vs casual conversation।",
    "questions": [
        q("Informal English কখন ব্যবহার করা উচিত?", ["Job interview-এ", "বন্ধু/পরিবারের সাথে কথা বলার সময়", "Academic essay-এ", "Official email-এ"], 1, "Informal = casual conversation, friends/family। Formal = official/work/academic।"),
        q("'Please inform me' — এটি কী ধরনের English?", ["Formal", "Informal", "Slang", "Colloquial"], 0, "'Please inform me' = formal। Informal = 'Let me know'।"),
        q("'Can you help me out?' — এটি কী ধরনের English?", ["Formal", "Informal", "Very formal", "Academic"], 1, "'Help me out' = informal phrasal verb। Formal = 'Could you kindly assist me?'"),
        q("Formal writing-এ 'I'll' না লিখে কী লেখা উচিত?", ["I will", "I shall", "I am going to", "I'm going to"], 0, "Contraction (I'll, don't, can't) formal-এ avoid করুন। Full form: I will, do not, cannot।"),
        q("'Dear Sir or Madam' — এটি কী ধরনের salutation?", ["Informal", "Formal", "Slang", "Casual"], 1, "'Dear Sir or Madam' = formal (যখন recipient-এর নাম জানা নেই)।"),
        q("Which is more formal? 'Please let me know' vs 'Please inform me'", ["Please let me know", "Please inform me", "একই level", "দুটোই informal"], 1, "'Inform' = 'let know'-এর চেয়ে formal।"),
        q("Which is more formal? 'I think' vs 'In my opinion'", ["I think", "In my opinion", "একই", "কোনোটাই formal নয়"], 1, "'In my opinion' = more formal than 'I think'।"),
        q("Which sentence is more informal?", ["I would like to request assistance.", "I need your help.", "Could you kindly assist me?", "I would appreciate your help."], 1, "'I need your help' = straightforward and informal।"),
        q("Formal email-এ 'Thanks' না লিখে কী লেখা উচিত?", ["Thx", "Thank you", "Thanks a lot", "Cheers"], 1, "Formal context-এ 'Thank you' full form ব্যবহার করুন।"),
        q("Which closing is formal?", ["Yours faithfully", "Cheers", "Later", "See ya"], 0, "'Yours faithfully' = formal ('Dear Sir/Madam' দিয়ে শুরু করলে)।"),
        q("Error: 'Dear Sir, I wanna apply for the job.' — ভুল?", ["Dear Sir", "wanna", "apply for", "the job"], 1, "'Wanna' = informal। Formal letter-এ 'want to' বা 'wish to' হবে।"),
        q("Error: 'I am writing to let u know about the meeting.' — ভুল?", ["am writing", "u", "let know", "the meeting"], 1, "'u' = SMS abbreviation। Formal-এ 'you' full form হবে।"),
        q("Error: 'Hello folks!' — formal email শুরু?", ["হ্যাঁ", "না, 'Dear Sir/Madam' হবে", "হ্যাঁ, খুব formal", "মাঝারি"], 1, "'Hello folks!' খুবই informal। Formal = 'Dear Sir/Madam'।"),
        q("Error: 'We regret to inform you that your application has been unsuccessful.' — 'regret to inform'?", ["খুব formal এবং সঠিক", "খুব informal", "ভুল phrase", "academic-এ চলে না"], 0, "'We regret to inform you' = formal এবং polite rejection-এর জন্য সঠিক।"),
        q("Fill (formal): 'I am writing to ___ about the vacancy.'", ["ask", "inquire", "know", "tell"], 1, "'Inquire' = formal। 'Ask' = less formal।"),
        q("Fill (formal): 'Please do not ___ to contact me.'", ["hesitate", "stop", "wait", "pause"], 0, "'Do not hesitate to contact me' = formal and polite।"),
        q("Fill (informal): '___ me know if you need anything.'", ["Inform", "Let", "Notify", "Tell"], 1, "'Let me know' = informal। 'Inform/Notify' = formal।"),
        q("Fill (formal): 'I would ___ your earliest response.'", ["appreciate", "like", "want", "need"], 0, "'I would appreciate your earliest response' = formal।"),
        q("অনুবাদ (formal): 'আমি আবেদন সম্পর্কে জানতে চাইছি।'", ["I want to know about the application.", "I am writing to inquire about the application.", "Tell me about the application.", "Let me know about the application."], 1, "'I am writing to inquire' = formal।"),
        q("অনুবাদ (informal): 'তোমার সাহায্য দরকার।'", ["I require your assistance.", "I need your help.", "I would appreciate your support.", "Could you kindly assist me?"], 1, "'I need your help' = informal এবং natural।")
    ]
}

# ===== mock_test_47 - Common Grammar Mistakes =====
ALL["mock_test_47"] = {
    "id": "mock_test_47", "testNumber": 47,
    "title": "Mock Test 47 - Common Grammar Mistakes",
    "description": "Common Grammar Mistakes নিয়ে ২০টি প্রশ্ন। Your vs You're, Its vs It's, There vs Their vs They're, Then vs Than, Affect vs Effect, Practice vs Practise, Advice vs Advise ইত্যাদি সাধারণ ভুল।",
    "questions": [
        q("'Your' এবং 'You're'-এর পার্থক্য কী?", ["একই অর্থ", "Your = possessive, You're = You are", "Your = You are, You're = possessive", "কোনো পার্থক্য নেই"], 1, "Your = তোমার/আপনার (possessive)। You're = You are (contraction)।"),
        q("___ going to love this movie!", ["Your", "You're", "Yours", "Your're"], 1, "'You are' → 'You're' (contraction)।"),
        q("The dog wagged ___ tail.", ["its", "it's", "its'", "its's"], 0, "'Its' = possessive of 'it'। 'It's' = it is।"),
        q("___ are many reasons to learn English.", ["There", "Their", "They're", "The're"], 0, "'There are' = exists। 'Their' = possessive। 'They're' = they are।"),
        q("This book is better ___ that one.", ["then", "than", "from", "as"], 1, "Comparison → 'than'। 'Then' = তখন।"),
        q("The weather will ___ our plans.", ["affect", "effect", "affect (verb)", "effect (noun)"], 0, "'Affect' = verb (প্রভাব ফেলা)। 'Effect' = noun (প্রভাব)।"),
        q("I need some ___ before the trip.", ["advice", "advise", "adviced", "advicing"], 0, "'Advice' = noun (পরামর্শ)। 'Advise' = verb (পরামর্শ দেওয়া)।"),
        q("Error: 'Its a beautiful day outside.' — ভুল?", ["Its", "beautiful", "day", "outside"], 0, "'Its' → 'It's' (It is)।"),
        q("Error: 'Their going to the market.' — ভুল?", ["Their", "going", "to", "the market"], 0, "'Their' → 'They're' (They are)।"),
        q("Error: 'I have less friends than her.' — ভুল?", ["I have", "less", "friends", "than her"], 1, "'Less' uncountable-এর জন্য। Countable (friends) → 'fewer'।"),
        q("Error: 'Each of the students have passed.' — ভুল?", ["Each", "of the students", "have", "passed"], 2, "'Each of' + singular verb → 'has'।"),
        q("Error: 'She don't like coffee.' — ভুল?", ["She", "don't", "like", "coffee"], 1, "She (3rd person) → 'doesn't'।"),
        q("Fill: '___ a long time since we met.'", ["Its", "It's", "Its'", "It is"], 1, "'It's' = It has / It is। 'It's been a long time'।"),
        q("Fill: 'The company has ___ own rules.'", ["its", "it's", "its'", "it is"], 0, "Company (its) → possessive।"),
        q("Fill: 'He ran fast, ___ he missed the bus.'", ["then", "than", "but", "so"], 0, "'Then' = তারপর / তখন (sequence)।"),
        q("Fill: 'Can you ___ me on this matter?'", ["advice", "advise", "adviced", "advicing"], 1, "'Advise' = verb (পরামর্শ দেওয়া)।"),
        q("Fill: 'He gave me some good ___.'", ["advice", "advise", "advices", "advised"], 0, "'Advice' = noun (uncountable) → 'some advice' (not advices)।"),
        q("Fill: 'The new policy will ___ everyone.'", ["affect", "effect", "affects", "effects"], 0, "'Will affect' = verb (প্রভাব ফেলবে)।"),
        q("অনুবাদ: 'তোমার ব্যাগটা সুন্দর।'", ["You're bag is nice.", "Your bag is nice.", "Yours bag is nice.", "Your're bag is nice."], 1, "'Your' = possessive → Your bag।"),
        q("অনুবাদ: 'তারা খুব খুশি।'", ["Their very happy.", "There very happy.", "They're very happy.", "The're very happy."], 2, "'They're' = They are।")
    ]
}

# ===== mock_test_48 - Confusing Words =====
ALL["mock_test_48"] = {
    "id": "mock_test_48", "testNumber": 48,
    "title": "Mock Test 48 - Confusing Words",
    "description": "Confusing Words নিয়ে ২০টি প্রশ্ন। Borrow vs Lend, Accept vs Except, Principal vs Principle, Stationary vs Stationery, Complement vs Compliment, Economic vs Economical, Historic vs Historical ইত্যাদি।",
    "questions": [
        q("Can I ___ your pen?", ["borrow", "lend", "take", "give"], 0, "'Borrow' = নিজে নেওয়া (কারো কাছ থেকে)। 'Lend' = অন্যকে দেওয়া।"),
        q("Could you ___ me your car?", ["borrow", "lend", "take", "give"], 1, "'Lend' = দেওয়া (অন্যকে)। 'Lend me your car'।"),
        q("Please ___ my apology.", ["accept", "except", "expect", "aspect"], 0, "'Accept' = গ্রহণ করা। 'Except' = ছাড়া।"),
        q("Everyone came ___ John.", ["accept", "except", "expect", "aspect"], 1, "'Except' = ছাড়া / বাদে।"),
        q("The ___ of this school is Mr. Khan.", ["principal", "principle", "principale", "prince"], 0, "'Principal' = প্রধান শিক্ষক। 'Principle' = নীতি।"),
        q("Honesty is an important ___.", ["principal", "principle", "principale", "prince"], 1, "'Principle' = নীতি / আদর্শ।"),
        q("I bought some ___ for the office.", ["stationary", "stationery", "station", "stationer"], 1, "'Stationery' = লেখার উপকরণ। 'Stationary' = স্থির।"),
        q("The car remained ___ at the light.", ["stationary", "stationery", "station", "stationer"], 0, "'Stationary' = স্থির/অচল।"),
        q("The red shirt ___ the blue one.", ["complements", "compliments", "completes", "competes"], 0, "'Complement' = পরিপূরক/সুসংগত। 'Compliment' = প্রশংসা।"),
        q("She ___ me on my new haircut.", ["complemented", "complimented", "completed", "competed"], 1, "'Compliment' = প্রশংসা করা।"),
        q("Error: 'Can you borrow me your book?' — ভুল?", ["Can you", "borrow me", "your book", "—"], 1, "'Borrow me' → 'Lend me'। Borrow = নেওয়া, Lend = দেওয়া।"),
        q("Error: 'Everyone accept John passed.' — ভুল?", ["Everyone", "accept", "John", "passed"], 1, "'Accept' → 'Except' (বাদে)।"),
        q("Error: 'The principle of the school is strict.' — ভুল?", ["The", "principle", "of the school", "is strict"], 1, "School-এর head = 'Principal'। 'Principle' = নীতি।"),
        q("Error: 'I need to bye some stationary.' — দুটি ভুল?", ["bye → buy", "stationary → stationery", "দুটোই", "কোনো ভুল নেই"], 2, "'Bye' = goodbye → 'Buy' (কেনা)। 'Stationary' = স্থির → 'Stationery'।"),
        q("Fill: 'Can I ___ your bicycle for a day?'", ["borrow", "lend", "loan", "rent"], 0, "Bicycle নেওয়া = 'borrow'।"),
        q("Fill: 'The hotel was nice, ___ for the noise.'", ["accept", "except", "expect", "aspect"], 1, "'Except for' = ছাড়া / বাদে।"),
        q("Fill: 'He ___ me on my success.'", ["complemented", "complimented", "completed", "competed"], 1, "সাফল্যে প্রশংসা = 'complimented'।"),
        q("Fill: 'The colors ___ each other perfectly.'", ["complement", "compliment", "complete", "compete"], 0, "রং পরস্পরকে complement করে (পরিপূরক)।"),
        q("অনুবাদ: 'আমি কি তোমার কলম ধার নিতে পারি?'", ["Can I lend your pen?", "Can I borrow your pen?", "Can I take your pen?", "Can I give your pen?"], 1, "নিজে নেওয়া = 'borrow'।"),
        q("অনুবাদ: 'সবাই আসবে রহিম ছাড়া।'", ["accept Rahim", "except Rahim", "expect Rahim", "aspect Rahim"], 1, "'Except' = ছাড়া / বাদে।")
    ]
}

# ===== mock_test_49 - Punctuation & Capitalization =====
ALL["mock_test_49"] = {
    "id": "mock_test_49", "testNumber": 49,
    "title": "Mock Test 49 - Punctuation & Capitalization",
    "description": "Punctuation ও Capitalization নিয়ে ২০টি প্রশ্ন। Period, Comma, Question Mark, Exclamation Mark, Apostrophe, Quotation Marks, Capital Letters, Proper Nouns — সঠিক ব্যবহার।",
    "questions": [
        q("Which sentence is correctly capitalized?", ["i live in dhaka.", "I live in Dhaka.", "I Live In Dhaka.", "i Live in dhaka."], 1, "Sentence শুরু capital I, proper noun 'Dhaka' capital।"),
        q("Which punctuation shows possession?", ["Comma", "Apostrophe", "Question mark", "Period"], 1, "Apostrophe (') possession দেখায়: 'John's book'।"),
        q("Choose the correctly punctuated:", ["He said, I am happy.", "He said, \"I am happy.\"", "He said \"I am happy.\"", "He said, \"I am happy\""], 1, "Comma + quotation marks + period inside quotes — সঠিক।"),
        q("What comes at the end of a question?", ["Period", "Question mark", "Exclamation mark", "Comma"], 1, "Question → ? (Question mark)।"),
        q("Which word should always be capitalized?", ["table", "apple", "Bangladesh", "running"], 2, "Proper noun (Bangladesh) সবসময় capital।"),
        q("'I'm' — apostrophe কী বোঝাচ্ছে?", ["কিছুই না", "'m' = am-এর সংক্ষিপ্ত রূপ", "পজেশন", "বিরাম"], 1, "'I'm' = I am। Apostrophe = missing letter (a) দেখায়।"),
        q("Error: 'i go to school everyday.' — ভুল?", ["i → I", "no period", "সব ভুল", "কোনো ভুল নেই"], 0, "'I' সবসময় capital। Sentence end-এ period প্রয়োজন।"),
        q("Error: 'Hello how are you?' — ভুল?", ["Hello → capital", "comma after Hello missing", "question mark ঠিক", "কোনো ভুল নেই"], 1, "'Hello,' — comma needed before 'how are you?'।"),
        q("Error: 'She said, I am tired.' — ভুল?", ["quotation marks নেই", "comma উচিত নয়", "She capital ঠিক", "period ঠিক নেই"], 0, "Direct Speech-এ quotation marks ('\"') লাগবে।"),
        q("Error: 'Its a lovely day.' — ভুল?", ["Its → It's", "Its ঠিক আছে", "day → Day", "a → an"], 0, "'Its' = possessive, 'It's' = It is। এখানে 'It's' হবে।"),
        q("Fill: '___ you coming to the party?'", ["Is", "Are", "Am", "Be"], 1, "Question start → 'Are you coming?'"),
        q("Fill: 'Please close the door___'", [".", "?", "!", ":"], 0, "Request/command → period (.)।"),
        q("Fill: 'What a beautiful view___'", [".", "?", "!", ":"], 2, "Exclamatory → ! (Exclamation mark)।"),
        q("Fill: '___ Monday is the first day.'", ["monday", "Monday", "MONDAY", "Mondays"], 1, "Day name (Monday) → capital letter।"),
        q("Fill: 'She said ___I am happy___' — সঠিক punctuation?", ["she said, \"I am happy.\"", "She said, ,I am happy.", "she said: I am happy", "She said I am happy"], 0, "Capital S + comma + quotation marks — সঠিক।"),
        q("Fill: 'Johns car is new' — সঠিক possessive?", ["Johns car", "John's car", "Johns' car", "John car"], 1, "John's car — apostrophe + s for possession।"),
        q("Fill: 'The childrens toys' — সঠিক?", ["childrens toys", "children's toys", "childrens' toys", "children toys"], 1, "'Children' plural (irregular) → 's যোগ: children's toys।"),
        q("Which needs capital?: 'My uncle lives in paris.'", ["My", "uncle", "lives", "paris"], 3, "Paris — proper noun, capital P।"),
        q("অনুবাদ: 'সে বলল, আমি খুশি।' (correct punctuation)", ["She said, i am happy.", "She said, \"I am happy.\"", "she said I am happy.", "She said: I am happy"], 1, "Capital S + comma + quotation marks + capital I + period।"),
        q("Error: 'I am from chittagong.' — ভুল?", ["I → capital ঠিক আছে", "chittagong → Chittagong (proper noun)", "period নেই", "—"], 1, "Chittagong — proper noun, capital C হবে।")
    ]
}

# ===== mock_test_50 - Sentence Transformation =====
ALL["mock_test_50"] = {
    "id": "mock_test_50", "testNumber": 50,
    "title": "Mock Test 50 - Sentence Transformation",
    "description": "Sentence Transformation নিয়ে ২০টি প্রশ্ন। Active ↔ Passive, Direct ↔ Indirect, Affirmative ↔ Negative, Simple ↔ Complex, Positive ↔ Comparative ↔ Superlative, Exclamatory ↔ Assertive transformation।",
    "questions": [
        q("Active: 'She writes a letter.' → Passive কী হবে?", ["A letter is written by her.", "A letter was written by her.", "A letter has been written by her.", "A letter is being written by her."], 0, "Present Indefinite → is/are + V3। 'A letter is written by her.'"),
        q("Active: 'He ate an apple.' → Passive কী হবে?", ["An apple is eaten by him.", "An apple was eaten by him.", "An apple has been eaten.", "An apple had been eaten."], 1, "Past Indefinite → was/were + V3। 'An apple was eaten by him.'"),
        q("Direct: 'He said, \"I am busy.\"' → Indirect কী হবে?", ["He said that he is busy.", "He said that he was busy.", "He said that I am busy.", "He said that I was busy."], 1, "'I' → 'he', Present 'am' → Past 'was'।"),
        q("Direct: 'She said, \"I will come.\"' → Indirect কী হবে?", ["She said that she will come.", "She said that she would come.", "She said that I will come.", "She said that I would come."], 1, "'Will' → 'would', 'I' → 'she'।"),
        q("Affirmative: 'He is honest.' → Negative কী হবে?", ["He is not honest.", "He is not dishonest.", "He is never honest.", "He is no honest."], 0, "'Is' → 'is not' (isn't)। 'He is not honest.'"),
        q("Negative: 'I do not like tea.' → Affirmative কী হবে?", ["I like tea.", "I dislike tea.", "I hate tea.", "I do like tea."], 0, "'Do not like' → 'like'।"),
        q("Positive: 'Rimi is as tall as Rina.' → Comparative?", ["Rimi is taller than Rina.", "Rina is taller than Rimi.", "Rimi is not as tall as Rina.", "Rimi is the tallest."], 0, "'As tall as' → 'taller than' (সমান → বড়)।"),
        q("Positive: 'No other girl is as beautiful as Mina.' → Superlative?", ["Mina is more beautiful.", "Mina is the most beautiful girl.", "Mina is beautiful.", "No girl is beautiful."], 1, "'As beautiful as' → 'the most beautiful'।"),
        q("Exclamatory: 'What a beautiful flower!' → Assertive?", ["It is a beautiful flower.", "What a beautiful flower it is!", "Is it a beautiful flower?", "How beautiful flower!"], 0, "'What a + adj + noun!' → 'It is a very + adj + noun.'"),
        q("Assertive: 'I wish I were a bird.' → Exclamatory?", ["If I were a bird!", "I were a bird!", "What a bird I am!", "How I wish I were a bird!"], 0, "'If I were a bird!' (Exclamatory)"),
        q("Simple: 'He came here and sat down.' → Complex?", ["He came here to sit down.", "He came here, and he sat down.", "When he came here, he sat down.", "He came here sitting down."], 2, "'When he came here, he sat down.' (adverb clause)"),
        q("Complex: 'If you study, you will pass.' → Simple?", ["Study to pass.", "Studying helps you pass.", "By studying, you will pass.", "You study and pass."], 2, "'If you study' → 'By studying' (gerund phrase)"),
        q("Active: 'The children are playing football.' → Passive?", ["Football is played by the children.", "Football is being played by the children.", "Football was played by the children.", "Football has been played."], 1, "Present Continuous → is/are + being + V3।"),
        q("Active: 'She has written a novel.' → Passive?", ["A novel is written by her.", "A novel was written by her.", "A novel has been written by her.", "A novel had been written."], 2, "Present Perfect → has/have + been + V3।"),
        q("Fill: 'I said to him, \"I know you.\"' → Indirect: 'I told him that I ___ him.'", ["know", "knew", "have known", "had known"], 1, "Present 'know' → Past 'knew'।"),
        q("Fill: 'He is too weak to walk.' → 'He is so weak that he ___ walk.'", ["cannot", "could not", "will not", "may not"], 0, "'Too + adj + to' → 'so + adj + that + can/cannot'।"),
        q("Fill: 'Nobody could solve the problem.' (Affirmative)", ["Everybody failed to solve the problem.", "Anybody could not solve it.", "All could not solve it.", "Nobody solved it."], 0, "'Nobody could' → 'Everybody failed'।"),
        q("Fill: 'She said, \"I am reading.\"' → 'She said that ___'", ["she is reading", "she was reading", "I am reading", "I was reading"], 1, "'I' → 'she', 'am reading' → 'was reading'।"),
        q("অনুবাদ (Transformation): 'মিমি রিমির চেয়ে লম্বা।' (Comparative → Positive)", ["Mimi is taller than Rimi.", "Rimi is as tall as Mimi.", "Rimi is not so tall as Mimi.", "Mimi is the tallest."], 2, "'Taller than' → 'not so tall as' (Positive)।"),
        q("অনুবাদ: 'আমি যদি পাখি হতাম!' → Exclamatory → Assertive", ["I wish I were a bird.", "I am a bird.", "I was a bird.", "I will be a bird."], 0, "'If I were a bird!' (Exclamatory) → 'I wish I were a bird.' (Assertive)")
    ]
}

# ===== mock_test_51 - Advanced Modals =====
ALL["mock_test_51"] = {
    "id": "mock_test_51", "testNumber": 51,
    "title": "Mock Test 51 - Advanced Modals (needn't, used to, ought to, dare)",
    "description": "Advanced Modal Verbs নিয়ে ২০টি প্রশ্ন। Needn't, Used to, Ought to, Dare, Had better, Would rather, Needn't have + V3, Didn't need to ইত্যাদি।",
    "questions": [
        q("'Needn't' modal-টির অর্থ কী?", ["প্রয়োজন", "প্রয়োজন নেই", "অবশ্যই", "হতে পারে"], 1, "'Needn't' = need not = প্রয়োজন নেই। যেমন: You needn't worry."),
        q("'Used to' modal-টির অর্থ কী?", ["বর্তমানে করি", "অতীতে করতাম (এখন করি না)", "ভবিষ্যতে করব", "সবসময় করি"], 1, "'Used to' = past habit (অতীত অভ্যাস যা এখন নেই)। যেমন: I used to smoke."),
        q("'Ought to' modal-টির অর্থ কী?", ["উচিত (should-এর মতো কিন্তু stronger)", "পারে", "চায়", "ঘটতে পারে"], 0, "'Ought to' = moral duty/obligation। যেমন: You ought to respect your parents."),
        q("'Dare' modal-টির অর্থ কী?", ["যত্ন নেওয়া", "সাহস করা", "দৌড়ানো", "পড়া"], 1, "'Dare' = have the courage to। যেমন: I dare not go there alone."),
        q("'Had better' modal-টির অর্থ কী?", ["ভালো ছিল/উচিত (strong advice)", "আগে ছিল", "পারে না", "চায় না"], 0, "'Had better' = should/উচিত (strong advice, with consequences)। যেমন: You had better see a doctor."),
        q("You ___ to buy so many things. We already have enough.", ["needn't", "needn't have bought", "don't need", "didn't need"], 0, "Present necessity নেই → 'needn't'।"),
        q("He ___ smoke heavily, but now he has quit.", ["used to", "would", "could", "might"], 0, "অতীত অভ্যাস (এখন নেই) → 'used to'।"),
        q("You ___ pay the bill by tomorrow. It's your duty.", ["ought to", "used to", "dare", "needn't"], 0, "Moral duty → 'ought to'।"),
        q("How ___ you speak to your mother like that!", ["dare", "need", "used", "ought"], 0, "'How dare you!' = সাহস করে কীভাবে! (anger/disbelief)"),
        q("I ___ go now or I'll miss the bus.", ["had better", "used to", "dare", "needn't"], 0, "Strong advice → 'had better' (না গেলে বাস মিস)।"),
        q("Error: 'You needn't to go there.' — ভুল?", ["You", "needn't to", "go there", "—"], 1, "'Needn't' modal → এর পরে 'to' লাগে না। 'You needn't go there.'"),
        q("Error: 'She used to smoked a lot.' — ভুল?", ["She", "used to", "smoked", "—"], 2, "'Used to' → এর পরে V1 (base form)। 'used to smoke' হবে, 'smoked' নয়।"),
        q("Error: 'He ought not go there.' — ভুল?", ["He", "ought not go", "there", "—"], 1, "'Ought to' negative = 'ought not to'। 'He ought not to go there.'"),
        q("Error: 'You had better to see a doctor.' — ভুল?", ["You", "had better to", "see", "a doctor"], 1, "'Had better' → এর পরে 'to' ছাড়া V1। 'You had better see a doctor.'"),
        q("Fill: 'You ___ have bought so many. It was unnecessary.' (ক্রয় করেছ, কিন্তু দরকার ছিল না)", ["needn't", "needn't have", "don't need", "mustn't"], 1, "অপ্রয়োজনীয় past action → 'needn't have + V3'।"),
        q("Fill: 'I ___ to play cricket when I was young.'", ["used", "would", "will", "shall"], 0, "'Used to' = past habit। 'I used to play cricket.'"),
        q("Fill: 'You ___ finish your homework before playing.'", ["ought to", "used to", "dare", "needn't"], 0, "'Ought to' = উচিত।"),
        q("Fill: 'I ___ rather stay home than go out.'", ["would", "used", "had better", "ought"], 0, "'Would rather' = বরং পছন্দ।"),
        q("অনুবাদ: 'তোমার চিন্তা করার প্রয়োজন নেই।'", ["You needn't worry.", "You used to worry.", "You dare not worry.", "You had better worry."], 0, "'Needn't' = প্রয়োজন নেই।"),
        q("অনুবাদ: 'সে আগে ধূমপান করত, কিন্তু এখন ছেড়ে দিয়েছে।'", ["He used to smoke, but now he quit.", "He smokes now.", "He never smoked.", "He will smoke."], 0, "'Used to' = past habit (এখন নেই)।")
    ]
}

# ===== mock_test_52 - Causative Verbs =====
ALL["mock_test_52"] = {
    "id": "mock_test_52", "testNumber": 52,
    "title": "Mock Test 52 - Causative Verbs (have/get something done)",
    "description": "Causative Verbs নিয়ে ২০টি প্রশ্ন। Have/get something done, Have/let/make someone do something, Get someone to do something — গঠন ও ব্যবহার।",
    "questions": [
        q("Causative 'have something done' structure কী?", ["Have + someone + V1", "Have + something + V3", "Have + V1 + something", "Have + Ving"], 1, "'Have + object + V3' = অন্যকে দিয়ে কাজ করানো। যেমন: I had my hair cut."),
        q("'I had my car repaired.' — এর অর্থ কী?", ["আমি নিজে গাড়ি মেরামত করলাম", "আমি অন্যকে দিয়ে গাড়ি মেরামত করালাম", "গাড়ি নিজেই মেরামত হলো", "গাড়ি মেরামত হচ্ছে"], 1, "'Had my car repaired' = causative (অন্যকে দিয়ে করানো)।"),
        q("'Get something done' structure কী?", ["Get + V3 + something", "Get + something + V3", "Get + someone + V1", "Get + V1 + something"], 1, "'Get + object + V3' = have something done-এর মতো কিন্তু less formal।"),
        q("'Make someone do something' অর্থ কী?", ["কাউকে কিছু করতে বাধ্য করা", "কাউকে কিছু করতে দেওয়া", "কাউকে কিছু করতে সাহায্য করা", "কাউকে কিছু করতে বলা"], 0, "'Make + someone + V1' = force/bang kora। যেমন: She made me cry."),
        q("'Let someone do something' অর্থ কী?", ["বাধ্য করা", "অনুমতি দেওয়া", "চাওয়া", "পড়া"], 1, "'Let + someone + V1' = allow/permit। যেমন: Let him go."),
        q("I need to ___ my hair cut.", ["have", "make", "let", "get"], 0, "'Have something done' — 'have my hair cut'।"),
        q("She ___ him clean the whole house.", ["made", "let", "had", "got"], 0, "'Made him clean' = তাকে পরিষ্কার করতে বাধ্য করল।"),
        q("My father ___ me use his car.", ["let", "made", "had", "got"], 0, "'Let me use' = অনুমতি দিল।"),
        q("I ___ my watch repaired yesterday.", ["had", "made", "let", "got"], 0, "'Had my watch repaired' — causative (past)।"),
        q("Can you ___ someone to help us?", ["get", "make", "let", "have"], 0, "'Get someone to do' = arrange for someone to help।"),
        q("Error: 'I had my hair cutted.' — ভুল?", ["I had", "my hair", "cutted", "—"], 2, "'Cut' → V3 = 'cut' (irregular)। 'cutted' ভুল। সঠিক: I had my hair cut."),
        q("Error: 'She made him to go.' — ভুল?", ["She made", "him", "to go", "—"], 2, "'Make + someone + V1' (to ছাড়া)। 'She made him go.'"),
        q("Error: 'Let him to speak.' — ভুল?", ["Let him", "to speak", "—", "—"], 1, "'Let + someone + V1' (to ছাড়া)। 'Let him speak.'"),
        q("Error: 'I got my car repair.' — ভুল?", ["I got", "my car", "repair", "—"], 2, "'Get something done' → V3 লাগবে। 'I got my car repaired.'"),
        q("Fill: 'I need to get my computer ___ (fix).'", ["fix", "fixed", "fixing", "fixes"], 1, "'Get + object + V3' → 'get my computer fixed'।"),
        q("Fill: 'The teacher ___ the students stay after class.'", ["made", "let", "had", "got"], 0, "'Made them stay' = বাধ্য করলেন।"),
        q("Fill: 'I ___ my house painted last month.'", ["had", "made", "let", "got"], 0, "'Had my house painted' — causative।"),
        q("Fill: 'She ___ her son play outside.'", ["let", "made", "had", "got"], 0, "'Let her son play' = অনুমতি দিল।"),
        q("অনুবাদ: 'আমি আমার চুল কাটিয়েছি।' (causative)", ["I cut my hair.", "I had my hair cut.", "I made my hair cut.", "I let my hair cut."], 1, "'Had my hair cut' = causative ( অন্যকে দিয়ে কাটানো)।"),
        q("অনুবাদ: 'সে তাকে যেতে বাধ্য করল।'", ["She let him go.", "She made him go.", "She had him go.", "She got him go."], 1, "'Made him go' = বাধ্য করল।")
    ]
}

# ===== mock_test_53 - Inversion =====
ALL["mock_test_53"] = {
    "id": "mock_test_53", "testNumber": 53,
    "title": "Mock Test 53 - Inversion (Negative Adverb Inversion)",
    "description": "Inversion নিয়ে ২০টি প্রশ্ন। Never, Hardly, Scarcely, No sooner, Not only, Rarely, Seldom, Only after, Not until, Only when — এদের inversion structure।",
    "questions": [
        q("Inversion কী?", ["'বাক্যের normal word order (Subject + Verb) বিপরীত করে Auxiliary + Subject + Main Verb'", "একটি negative sentence", "একটি question", "একটি passive"], 0, "Inversion = normal word order reversed when negative adverb starts a sentence."),
        q("Inversion সাধারণত কোথায় হয়?", ["Affirmative sentence-এ", "Negative adverb দিয়ে sentence শুরু করলে", "Question-এ সবসময়", "Passive sentence-এ"], 1, "Negative adverbs (Never, Rarely, Hardly) দিয়ে শুরু করলে inversion হয়।"),
        q("'Never have I seen such beauty.' — এখানে inversion কেন?", ["'Never' negative adverb, তাই Auxiliary (have) Subject (I)-এর আগে চলে এসেছে", "এটি question", "এটি passive", "এটি conditional"], 0, "'Never' negative adverb → Auxiliary (have) comes before Subject (I)."),
        q("'No sooner ___ the train than it started raining.'", ["did we leave", "we left", "we had left", "had we left"], 3, "'No sooner' → inversion: 'had + subject + V3'।"),
        q("'Not until I saw her ___ I realize my mistake.'", ["did", "had", "was", "I did"], 0, "'Not until' + clause + inversion in main clause। 'did I realize'।"),
        q("'Only after ___ did I understand.'", ["he explained", "did he explain", "he did explain", "explained he"], 0, "'Only after' + clause (no inversion) + inverted main clause।"),
        q("'Hardly had I arrived ___ it started raining.'", ["when", "than", "then", "before"], 0, "'Hardly... when...' — fixed pair।"),
        q("'Scarcely ___ we sat down when the phone rang.'", ["had", "did", "was", "have"], 0, "'Scarcely' + had + subject ('Scarcely had we sat down')।"),
        q("'Rarely ___ such a talented player.'", ["have I seen", "I have seen", "I saw", "saw I"], 0, "'Rarely' → Inversion: 'have I seen'।"),
        q("'Not only did he pass, but he ___ top.'", ["got", "gets", "had got", "get"], 0, "'Not only + inversion + but + normal clause'।"),
        q("Error: 'Never I have seen such a mess.' — ভুল?", ["Never", "I have", "seen", "such a mess"], 1, "'Never' → inversion: 'Never have I seen' হবে।"),
        q("Error: 'No sooner we left than it rained.' — ভুল?", ["No sooner", "we left", "than", "it rained"], 1, "'No sooner' → inversion: 'No sooner had we left' হবে।"),
        q("Error: 'Only after I finished, I realized my mistake.' — ভুল?", ["Only after", "I finished", "I realized", "my mistake"], 2, "'Only after...' → main clause-এ inversion: 'did I realize'।"),
        q("Error: 'Hardly I had arrived when it started raining.' — ভুল?", ["Hardly I had", "arrived", "when", "started raining"], 0, "'Hardly' → inversion: 'Hardly had I arrived' হবে।"),
        q("Fill: 'Seldom ___ (I/see) such dedication.'", ["I see", "do I see", "I have seen", "have I seen"], 3, "'Seldom' → inversion: 'have I seen'।"),
        q("Fill: 'Not until I read the letter ___ (I/understand) the truth.'", ["I understood", "I understand", "did I understand", "I did understand"], 2, "'Not until...' + inverted main clause: 'did I understand'।"),
        q("Fill: 'Only by working hard ___ (you/succeed).'", ["you will succeed", "will you succeed", "you succeed", "you succeeded"], 1, "'Only by + Ving' → inversion in main: 'will you succeed'।"),
        q("Fill: 'No sooner had I gone to bed ___ the phone rang.'", ["when", "than", "then", "after"], 1, "'No sooner... than...' — fixed pair।"),
        q("অনুবাদ (Inversion): 'আমি কখনো এত সুন্দর দৃশ্য দেখিনি।'", ["Never I have seen such a beautiful view.", "Never have I seen such a beautiful view.", "Never I saw such beautiful view.", "Never saw I such beautiful view."], 1, "'Never' → inversion: 'Never have I seen'।"),
        q("অনুবাদ (Inversion): 'কঠোর পরিশ্রম করলেই তুমি সফল হবে।'", ["Only by working hard you will succeed.", "Only by working hard will you succeed.", "Only working hard you succeed.", "Only hard work you succeed."], 1, "'Only by' + Ving → inversion: 'will you succeed'।")
    ]
}

# ===== mock_test_54 - Subjunctive Mood =====
ALL["mock_test_54"] = {
    "id": "mock_test_54", "testNumber": 54,
    "title": "Mock Test 54 - Subjunctive Mood",
    "description": "Subjunctive Mood নিয়ে ২০টি প্রশ্ন। Wish, If only, As if/though, Suggest/Recommend/Insist that + V1, It's time + V2, Would rather that + V2 ইত্যাদি।",
    "questions": [
        q("Subjunctive Mood কী বোঝায়?", ["বাস্তব ঘটনা", "অবাস্তব/কাল্পনিক/ইচ্ছাপূর্ণ অবস্থা", "অতীত ঘটনা", "ভবিষ্যৎ নিশ্চিততা"], 1, "Subjunctive = unreal/wishful/hypothetical situations।"),
        q("'I wish I ___ a bird.' — সঠিক verb?", ["am", "was", "were", "will be"], 2, "'Wish' + were (subjunctive) — Present unreal।"),
        q("'She acts as if she ___ the boss.' — সঠিক?", ["is", "was", "were", "will be"], 2, "'As if/though' + were (subjunctive) — unreal comparison।"),
        q("'I suggest that he ___ a doctor.' — সঠিক?", ["sees", "see", "saw", "seeing"], 1, "'Suggest that' + V1 (subjunctive base form)।"),
        q("'It's time you ___ to bed.' — সঠিক?", ["go", "went", "going", "goes"], 1, "'It's time + subject + V2 (Past) — Present subjunctive।"),
        q("'I would rather you ___ here.' — সঠিক?", ["stay", "stayed", "staying", "stays"], 1, "'Would rather + subject + V2 — different subject subjunctive।"),
        q("I wish I ___ harder for the exam.", ["studied", "had studied", "study", "will study"], 1, "'Wish' + Past Perfect (had + V3) — past regret।"),
        q("If only I ___ more time!", ["have", "had", "having", "will have"], 1, "'If only' + Past (had) — present wish বা Past Perfect — past wish।"),
        q("He talks as if he ___ everything.", ["knows", "knew", "knowing", "will know"], 1, "'As if' + Past (knew) — present unreal।"),
        q("The doctor recommended that she ___ more water.", ["drinks", "drink", "drank", "drinking"], 1, "'Recommend that' + V1 (subjunctive base) — 'that she drink'।"),
        q("Error: 'I wish I am a bird.' — ভুল?", ["I wish", "I am", "a bird", "—"], 1, "'Wish' → were (subjunctive)। 'I wish I were a bird.'"),
        q("Error: 'She insisted that he goes with her.' — ভুল?", ["She insisted", "that he goes", "with her", "—"], 1, "'Insist that' + V1 (base)। 'that he go' — not 'goes'।"),
        q("Error: 'It's time we leave now.' — ভুল?", ["It's time", "we leave", "now", "—"], 1, "'It's time + subject + V2 (Past) → 'we left'।"),
        q("Error: 'He behaves as if he is rich.' — ভুল?", ["He behaves", "as if he is", "rich", "—"], 1, "'As if' → were (subjunctive)। 'as if he were rich'।"),
        q("Fill: 'I suggest that the meeting ___ (be) postponed.'", ["is", "be", "was", "will be"], 1, "'Suggest that + V1 (base)' → 'that the meeting be postponed'।"),
        q("Fill: 'If only I ___ (listen) to my mother!'", ["listened", "had listened", "listen", "will listen"], 1, "'If only + Past Perfect' — past regret। 'If only I had listened'।"),
        q("Fill: 'It's high time you ___ (start) preparing.'", ["start", "started", "starting", "starts"], 1, "'It's high time + V2' — 'you started'।"),
        q("Fill: 'He wishes he ___ (can) fly.'", ["can", "could", "will", "shall"], 1, "'Wish' + could (subjunctive)। 'he could fly'।"),
        q("অনুবাদ: 'আমি যদি আরও সময় পেতাম!'", ["I wish I have more time.", "I wish I had more time.", "I wish I will have time.", "I wish I am having time."], 1, "'Wish + had' — present wish (অবাস্তব)।"),
        q("অনুবাদ: 'সে পরামর্শ দিল যে সে ডাক্তার দেখুক।'", ["He suggested that she sees a doctor.", "He suggested that she see a doctor.", "He suggested that she saw a doctor.", "He suggested that she will see a doctor."], 1, "'Suggest that + V1 (base)' — 'that she see'।")
    ]
}

# ===== mock_test_55 - Advanced Mixed Review =====
ALL["mock_test_55"] = {
    "id": "mock_test_55", "testNumber": 55,
    "title": "Mock Test 55 - Advanced Mixed Review",
    "description": "Level 3 (Test 41-54) মিশ্র ২০টি প্রশ্ন। Phrasal Verbs, Idioms, Collocations, Formal/Informal, Common Mistakes, Confusing Words, Punctuation, Sentence Transformation, Advanced Modals, Causative, Inversion, Subjunctive — সব টপিক থেকে।",
    "questions": [
        q("Which is correct collocation?", ["I did a decision.", "I made a decision.", "I took a decision.", "I had a decision."], 1, "'Make a decision' — সঠিক collocation।"),
        q("'Piece of cake' অর্থ কী?", ["খুব কঠিন", "খুব সহজ", "খুব সুন্দর", "খুব মজার"], 1, "'Piece of cake' = very easy।"),
        q("'He gave up smoking' — 'gave up' অর্থ কী?", ["ছেড়ে দিয়েছে", "নিয়েছে", "করেছে", "দেখেছে"], 0, "'Give up' = quit = ছেড়ে দেওয়া।"),
        q("Which is formal?", ["I need your help.", "I would like to request your assistance.", "Help me!", "I want help."], 1, "'I would like to request your assistance' = formal।"),
        q("'Your' vs 'You're' — কোনটি সঠিক?", ["___ a genius! (You're/Your)", "___ bag is here. (You're/Your)", "You're = possessive, Your = You are", "একই অর্থ"], 0, "'You're a genius!' = You are a genius."),
        q("'Its' vs 'It's' — কোনটি সঠিক?", ["___ raining outside. (Its/It's)", "The dog wagged ___ tail. (its/it's)", "It's = possessive, Its = It is", "একই"], 1, "'It's raining' = It is raining. 'its tail' = possessive।"),
        q("'Can I borrow your pen?' — 'borrow' অর্থ কী?", ["দেওয়া", "ধার নেওয়া", "কেনা", "বিক্রি করা"], 1, "'Borrow' = ধার নেওয়া (নিজে নেওয়া)।"),
        q("Error Detection: 'She don't like tea.' — ভুল কী?", ["She", "don't", "like", "tea"], 1, "She (3rd person) → 'doesn't'। 'She doesn't like tea.'"),
        q("Inversion: 'Never ___ such a beautiful place.'", ["I have seen", "have I seen", "I saw", "saw I"], 1, "'Never' → inversion: 'have I seen'।"),
        q("Causative: 'I ___ my car repaired yesterday.'", ["had", "made", "let", "got"], 0, "'Had my car repaired' — causative (past)।"),
        q("Subjunctive: 'I suggest that he ___ a doctor.'", ["sees", "see", "saw", "seeing"], 1, "'Suggest that + V1 (base)' → 'see'।"),
        q("Phrasal Verb: 'The meeting was ___ off due to rain.'", ["called", "put", "turned", "given"], 0, "'Called off' = বাতিল করা।"),
        q("Idiom: 'I'm feeling ___ the weather.'", ["under", "over", "on", "in"], 0, "'Under the weather' = অসুস্থ বোধ করা।"),
        q("Advanced Modal: 'You ___ have told me earlier. I was worried.'", ["should", "ought to", "needn't", "dare"], 0, "'Should have + V3' = regret/criticism about past।"),
        q("Collocation: 'Please ___ attention to the lesson.'", ["make", "do", "pay", "take"], 2, "'Pay attention' = মনোযোগ দেওয়া।"),
        q("Transformation: Active: 'She wrote a letter.' → Passive?", ["A letter is written.", "A letter was written by her.", "A letter has been written.", "A letter had been written."], 1, "Past → was/were + V3। 'was written'।"),
        q("Formal/Informal: Which is formal?", ["Thanks", "Thank you", "Thx", "Thanks a lot"], 1, "'Thank you' = formal। 'Thanks' = less formal।"),
        q("Confusing Words: 'The ___ of the school is Mr. Khan.'", ["principal", "principle", "principale", "prince"], 0, "'Principal' = প্রধান শিক্ষক। 'Principle' = নীতি।"),
        q("Punctuation: Correctly punctuated?", ["He said I am happy.", "He said, I am happy.", "He said, \"I am happy.\"", "He said \"I am happy.\""], 2, "Direct Speech → comma + quotation marks।"),
        q("অনুবাদ: 'সে আগে এখানে থাকত, কিন্তু এখন থাকে না।'", ["She used to live here.", "She lives here.", "She will live here.", "She never lived here."], 0, "'Used to' = past habit (now gone)।")
    ]
}

# ===== mock_test_56_through_70 helper =====
# Generate speaking/functional tests 56-70

ALL["mock_test_56"] = {
    "id": "mock_test_56", "testNumber": 56,
    "title": "Mock Test 56 - Self Introduction",
    "description": "Self Introduction নিয়ে ২০টি প্রশ্ন। নিজের নাম, পেশা, শখ, পরিবার, শিক্ষা, দক্ষতা ইত্যাদি সম্পর্কে বলার সঠিক ইংরেজি expression।",
    "questions": [
        q("Self introduction শুরু করার সঠিক উপায় কী?", ["My name is...", "I am called...", "Myself...", "I name is..."], 0, "'My name is...' বা 'I am...' — সবচেয়ে সাধারণ এবং সঠিক।"),
        q("নিজের পেশা বলার সঠিক উপায় কী?", ["I am a doctor.", "I am doctor.", "My profession is doctor.", "I work doctor."], 0, "'I am a/an + profession' — article 'a/an' লাগবে।"),
        q("নিজের শখ (hobby) বলার সঠিক উপায় কী?", ["I hobby is reading.", "My hobby is reading.", "I am hobby reading.", "My hobby reading."], 1, "'My hobby is + Ving' — 'My hobby is reading.'"),
        q("নিজের বয়স বলার সঠিক উপায় কী?", ["I have 25 years.", "I am 25 years old.", "My age is 25 years.", "I 25 years."], 1, "'I am + age + years old' — 'I am 25 years old.'"),
        q("নিজের শহর বলার সঠিক উপায় কী?", ["I live in Dhaka.", "I live at Dhaka.", "I am live in Dhaka.", "I living in Dhaka."], 0, "'I live in + city' — 'I live in Dhaka.'"),
        q("ভাই/বোন আছে জানাতে বলবেন কীভাবে?", ["I have one brother.", "I am one brother.", "My brother is one.", "There brother one."], 0, "'I have + number + sibling(s)' — 'I have one brother.'"),
        q("নিজের শিক্ষা সম্পর্কে বলার সঠিক উপায়?", ["I studied at Dhaka University.", "I am study at DU.", "My study in DU.", "I study at DU."], 0, "'I studied (Past) / I am studying (Present) at/from...'"),
        q("'Nice to meet you' — এর সঠিক উত্তর কী?", ["Nice to meet you too.", "Thank you.", "Yes, nice.", "I am fine."], 0, "'Nice to meet you too' — সঠিক reply।"),
        q("পড়ার অভ্যাস সম্পর্কে বলবেন কীভাবে?", ["I enjoy reading books.", "I like read books.", "I reading books.", "My hobby read books."], 0, "'Enjoy + Ving' বা 'Like to + V1' — 'I enjoy reading books.'"),
        q("ভাষার দক্ষতা বলার সঠিক উপায়?", ["I can speak English and Bengali.", "I speak English and Bengali.", "Both", "I can speaking English."], 0, "'I can speak + languages' বা 'I speak + languages' — উভয়ই সঠিক।"),
        q("Error: 'My name is Rahman. I am student.' — ভুল?", ["My name is", "I am student", "—", "—"], 1, "'I am a student' হবে (article 'a' লাগবে)।"),
        q("Error: 'I am 20 years old. I am from Bangladesh.' — সঠিক?", ["সঠিক", "ভুল, I am from Bangladesh ঠিক না", "ভুল, years old ঠিক না", "উভয়ই ভুল"], 0, "'I am 20 years old. I am from Bangladesh.' — সম্পূর্ণ সঠিক।"),
        q("Error: 'My hobby is to reading books.' — ভুল?", ["My hobby is", "to reading", "books", "—"], 1, "'My hobby is reading' (Gerund) বা 'My hobby is to read' (Inf)। 'to reading' ভুল।"),
        q("Error: 'I have one sister and one brother.' — সঠিক?", ["সঠিক", "ভুল, sister brother before number", "ভুল, have not correct", "—"], 0, "'I have one sister and one brother.' — সম্পূর্ণ সঠিক।"),
        q("Fill: 'I am a student ___ Dhaka College.'", ["in", "at", "of", "from"], 1, "'At' = institution-এ। 'At Dhaka College' (BrE) বা 'in' (AmE) দুই চলে।"),
        q("Fill: 'I want to be a ___ in the future.'", ["doctor", "doctorate", "doctoring", "doctors"], 0, "'A doctor' — 'Be + a/an + profession'।"),
        q("Fill: 'I am good ___ playing football.'", ["in", "at", "on", "with"], 1, "'Good at + Ving' — নিজের দক্ষতা বোঝাতে।"),
        q("Fill: 'I come ___ a small family.'", ["from", "in", "of", "at"], 0, "'Come from' = থেকে আসা। 'I come from a small family.'"),
        q("অনুবাদ: 'আমার নাম রহিম। আমি একজন ছাত্র।'", ["My name Rahim. I am student.", "My name is Rahim. I am a student.", "I name is Rahim. I student.", "Myself Rahim. I am student."], 1, "'My name is Rahim. I am a student.' — সঠিক introduction।"),
        q("অনুবাদ: 'আমি ইংরেজি এবং বাংলা উভয় ভাষায় কথা বলতে পারি।'", ["I speak English and Bengali.", "I can speak both English and Bengali.", "I speak both language.", "I can speaking English and Bengali."], 1, "'I can speak both...and...' = উভয় ভাষায় কথা বলতে পারি।")
    ]
}

# ===== mock_test_57 - 70 (compact remaining) =====
# Tailored to each functional topic with 20 questions each

# 57: Daily Routine
daily_q = []
for i, (q_text, opts, corr, expl) in enumerate([
    ("সকালে ঘুম থেকে ওঠাকে ইংরেজিতে কী বলে?", ["Wake up", "Get up", "Stand up", "Both wake up/get up"], 3, "'Wake up' = জেগে ওঠা, 'Get up' = বিছানা থেকে ওঠা। উভয়ই ব্যবহৃত হয়।"),
    ("'I ___ my teeth every morning.' (ব্রাশ করা)", ["wash", "brush", "clean", "rub"], 1, "'Brush teeth' = দাঁত ব্রাশ করা — সঠিক collocation।"),
    ("সকালের নাস্তা খাওয়ার সঠিক ইংরেজি কী?", ["Have breakfast", "Eat breakfast", "Take breakfast", "Get breakfast"], 0, "'Have breakfast' = সবচেয়ে common collocation।"),
    ("'I go to school ___ bus.'", ["in", "on", "by", "with"], 2, "'By bus' = transport-এর জন্য 'by'।"),
    ("কাজ শেষে বাড়ি ফেরাকে ইংরেজিতে কী বলে?", ["Come back home", "Go back home", "Return home", "সবগুলোই সঠিক"], 3, "'Come back/go back/return home' — সবগুলোই সঠিক।"),
    ("রাতে ঘুমাতে যাওয়ার সঠিক ইংরেজি কী?", ["Go to sleep", "Go to bed", "Sleep", "Go sleeping"], 1, "'Go to bed' = ঘুমাতে যাওয়া (শোওয়ার জন্য)। 'Go to sleep' = ঘুমিয়ে পড়া।"),
    ("'I usually ___ at 7 AM.' (জাগি)", ["wake up", "get up", "stand up", "sit up"], 0, "'Wake up' = জেগে ওঠা। 'Usually' = অভ্যাসগত কাজ।"),
    ("'I have lunch ___ noon.'", ["in", "at", "on", "by"], 1, "'At noon' = নির্দিষ্ট সময় (12 PM)।"),
    ("স্নান করাকে ইংরেজিতে কী বলে?", ["Take a shower", "Take a bath", "Have a shower", "সবগুলোই সঠিক"], 3, "'Take a shower/bath' বা 'Have a shower/bath' — সবগুলোই সঠিক।"),
    ("'I ___ my homework after dinner.'", ["make", "do", "take", "have"], 1, "'Do homework' = বাড়ির কাজ করা — সঠিক collocation।"),
    ("Error: 'I every day go to school.' — ক্রম/order ভুল?", ["I every day go", "to school", "—", "—"], 0, "Adverb of frequency subject-এর পরে বসে: 'I go to school every day.'"),
    ("Error: 'I brush my tooth every day.' — ভুল?", ["brush", "my tooth", "every day", "—"], 1, "'Tooth' singular → 'teeth' plural হবে। 'Brush my teeth'।"),
    ("Error: 'I am go to school every day.' — ভুল?", ["I am go", "to school", "every day", "—"], 0, "'Am go' → 'go' (Present Indefinite) কারণ এটি habit। 'I go to school every day.'"),
    ("Error: 'I always late for school.' — ভুল?", ["I always late", "for school", "—", "—"], 0, "'I am always late' — 'am' verb লাগবে।"),
    ("Fill: 'I ___ (take) a shower every morning.'", ["take", "takes", "am taking", "took"], 0, "Every morning → Present Indefinite (habit): 'I take'।"),
    ("Fill: 'He ___ (go) to office at 9 AM.'", ["go", "goes", "going", "went"], 1, "He (3rd person) → 'goes'।"),
    ("Fill: 'I usually ___ (have) dinner at 8 PM.'", ["have", "has", "am having", "had"], 0, "'I have' — Present Indefinite for habit।"),
    ("Fill: 'After breakfast, I ___ (leave) for school.'", ["leave", "leaves", "am leaving", "left"], 0, "'I leave' — routine action।"),
    ("অনুবাদ: 'আমি প্রতিদিন সকাল ৭টায় জেগে উঠি।'", ["I wake up at 7 AM every day.", "I am waking up at 7 AM.", "I woke up at 7 AM.", "I wakes up at 7 AM."], 0, "'I wake up at 7 AM every day' — Present Indefinite (habit)।"),
    ("অনুবাদ: 'সে সাধারণত রাত ১০টায় ঘুমাতে যায়।'", ["He usually go to bed at 10 PM.", "He usually goes to bed at 10 PM.", "He is going to bed at 10 PM.", "He went to bed at 10 PM."], 1, "He + goes (Present Indefinite) + usually (adverb of frequency) -> সঠিক।")
]):
    daily_q.append(q(q_text, opts, corr, expl))

ALL["mock_test_57"] = {
    "id": "mock_test_57", "testNumber": 57,
    "title": "Mock Test 57 - Daily Routine",
    "description": "Daily Routine নিয়ে ২০টি প্রশ্ন। প্রতিদিনের কাজ, সময়সূচী, অভ্যাস বর্ণনার সঠিক ইংরেজি expression, adverb of frequency, time preposition।",
    "questions": daily_q
}

# 58: At the Restaurant
rest_q = []
for item in [
    q("রেস্টুরেন্টে Food order দেওয়ার আগে কী বলবেন?", ["I want food.", "I would like to order.", "Give me food.", "Food please."], 1, "'I would like to order.' = polite way to start ordering."),
    q("ভাত অর্ডার করতে চাইলে কী বলবেন?", ["I want rice.", "I'd like some rice, please.", "Give me rice.", "Rice now."], 1, "'I'd like some rice, please.' = polite order."),
    q("'Could I have the menu, please?' — এটি কী ধরনের request?", ["Polite/Formal", "Rude", "Informal", "Slang"], 0, "'Could I...' = polite request।"),
    q("বিল চাওয়ার সঠিক উপায় কী?", ["Give me bill.", "I want bill.", "Could I have the bill, please?", "Bill here."], 2, "'Could I have the bill, please?' = polite way to ask for check."),
    q("কোনো dish সম্পর্কে জানতে চাইলে কী বলবেন?", ["What is this?", "Can you tell me what's in this dish?", "I want to know.", "Explain this."], 1, "'Can you tell me what's in this dish?' = polite inquiry."),
    q("ওয়েটারকে ডাকার সঠিক উপায় কী?", ["Hey!", "Excuse me!", "Waiter!", "Come here!"], 1, "'Excuse me!' = polite way to get server's attention."),
    q("'I'll have the chicken curry.' — এটি কী বোঝাচ্ছে?", ["আমি মুরগির তরকারি খাব", "আমি মুরগির তরকারি অর্ডার দিচ্ছি", "আমি মুরগির তরকারি রান্না করব", "আমি মুরগির তরকারি পছন্দ করি"], 1, "'I'll have...' = I will order and eat it — restaurant-এ order দেওয়ার common phrase।"),
    q("Reservation করার সঠিক বাক্য কোনটি?", ["I want to book a table.", "I'd like to reserve a table for two.", "Give me table.", "Table for me."], 1, "'I'd like to reserve a table for two.' = polite reservation request।"),
    q("খাবার ভালো না হলে complaint করার সঠিক উপায়?", ["This food is bad!", "I'm sorry, but this dish is not what I expected.", "Bad food!", "I don't like."], 1, "Polite complaint: 'I'm sorry, but...' + explain the problem."),
    q("'The food was delicious!' — এর অর্থ কী?", ["খাবারটা ভয়ংকর ছিল", "খাবারটা সুস্বাদু ছিল", "খাবারটা নষ্ট ছিল", "খাবারটা ঠান্ডা ছিল"], 1, "'Delicious' = সুস্বাদু। 'The food was delicious!'"),
    q("Error: 'Give me a glass of water.' — বাক্যটি কেমন?", ["Polite", "Too direct/rude for formal setting", "Very formal", "নর্মাল"], 1, "'Give me' খুব direct/rude। 'Could I have a glass of water, please?' বেশি polite।"),
    q("Error: 'I am wanting to order.' — ভুল কেন?", ["I am wanting → I want (stative verb)", "want-এ ing হয় না", "দুটোই", "—"], 0, "'Want' stative verb → Continuous হয় না। 'I want to order.'"),
    q("Error: 'I have a reservation name is Karim.' — ভুল?", ["I have a reservation", "name is Karim", "—", "—"], 1, "'I have a reservation under the name Karim.' — 'under the name' phrase ব্যবহার করা উচিত।"),
    q("Error: 'The food is very spicy for me.' — সঠিক?", ["সঠিক", "'Too spicy for me' হবে", "'Very spicy' ভুল", "—"], 1, "'The food is too spicy for me.' = অতিরিক্ত ঝাল। 'Very spicy' = খুব ঝাল, কিন্তু complaint-এর জন্য 'too' বেশি উপযুক্ত।"),
    q("Fill: 'I'd like to ___ a table for two.'", ["book", "take", "keep", "have"], 0, "'Book/Reserve a table' = টেবিল বুক করা।"),
    q("Fill: 'Could I have the ___ (বিল), please?'", ["bill", "menu", "food", "water"], 0, "'The bill/check' = বিল।"),
    q("Fill: 'I'll ___ the fish curry.'", ["take", "have", "eat", "get"], 1, "'I'll have the...' = order দেওয়ার standard phrase।"),
    q("Fill: 'The service was ___ (ধীর).'", ["slow", "fast", "good", "bad"], 0, "'Slow service' = ধীর সেবা — complaint-এ ব্যবহার হয়।"),
    q("অনুবাদ: 'আমি কি মেনু দেখতে পারি?'", ["I want to see menu.", "Could I see the menu, please?", "Give me menu.", "Menu please."], 1, "'Could I see the menu, please?' = polite request।"),
    q("অনুবাদ: 'আপনার স্পেশালিটি কী?'", ["What is special?", "What is your specialty?", "Special food?", "Tell specialty."], 1, "'What is your specialty?' = restaurant-এর বিশেষ খাবার জানতে চাওয়া।")
]:
    rest_q.append(item)
ALL["mock_test_58"] = {
    "id": "mock_test_58", "testNumber": 58,
    "title": "Mock Test 58 - At the Restaurant",
    "description": "Restaurant Scenario নিয়ে ২০টি প্রশ্ন। Order দেওয়া, Bill চাওয়া, Complaint করা, Reservation করা — প্রয়োজনীয় English expression।",
    "questions": rest_q
}

# ===== 59: Airport/Hotel =====
ALL["mock_test_59"] = {
    "id": "mock_test_59", "testNumber": 59,
    "title": "Mock Test 59 - At the Airport / Hotel",
    "description": "Airport ও Hotel Scenario নিয়ে ২০টি প্রশ্ন। Check-in, Reservation, Boarding pass, Luggage, Room booking, Check-out ইত্যাদি expression।",
    "questions": [
        q("এয়ারপোর্টে Check-in করার সময় কী বলবেন?", ["I want to check in.", "I'd like to check in for my flight.", "Check in me.", "I check in."], 1, "'I'd like to check in for my flight to...' = polite check-in request।"),
        q("Boarding pass কী?", ["এক ধরনের পাসপোর্ট", "বিমানে ওঠার অনুমতি পত্র", "ভিসা", "টিকিট"], 1, "Boarding pass = বিমানে ওঠার জন্য প্রয়োজনীয় pass।"),
        q("'How much luggage am I allowed?' — এটা কী বোঝাচ্ছে?", ["কত লাগেজ নেওয়া যাবে", "লাগেজ কত বড়", "লাগেজ কোথায়", "লাগেজ কত দামি"], 0, "'How much luggage am I allowed?' = luggage allowance সম্পর্কে জানতে চাওয়া।"),
        q("হোটেলে Check-in করার সঠিক বাক্য?", ["I want to check in.", "I'd like to check in, please. I have a reservation.", "Give me room.", "I check in now."], 1, "'I'd like to check in, please. I have a reservation under...' = polite check-in।"),
        q("রুম বুকিং করার সঠিক উপায়?", ["I'd like to book a room.", "I want room.", "Give me room.", "Room please."], 0, "'I'd like to book/reserve a room.' = polite booking।"),
        q("'Is breakfast included?' — এটা কী বোঝাচ্ছে?", ["নাস্তা তৈরি আছে?", "নাস্তা কি মূল্যের মধ্যে আছে?", "নাস্তা কোথায়?", "নাস্তায় কী আছে?"], 1, "'Is breakfast included?' = নাস্তা কি মূল্যের সাথে অন্তর্ভুক্ত?"),
        q("রুম নিয়ে problem থাকলে কী বলবেন?", ["Room is bad.", "There seems to be a problem with my room.", "Bad room.", "Fix room."], 1, "'There seems to be a problem...' = polite way to complain।"),
        q("Check-out করার সঠিক সময় জানতে চাইলে?", ["What is check out time?", "When is check-out?", "Check-out time please?", "সবগুলোই সঠিক"], 3, "'What is check-out time?' বা 'When is check-out?' — সকল variant সঠিক।"),
        q("'Could I have an extra towel?' — এটি কী ধরনের request?", ["Rude", "Polite request", "Complaint", "Order"], 1, "'Could I have...?' = polite request for an extra towel।"),
        q("লাগেজ নিয়ে সাহায্য চাইতে কী বলবেন?", ["Help me.", "Could I get some help with my luggage?", "Luggage help.", "Help luggage."], 1, "'Could I get some help with my luggage?' = polite request for porter/help।"),
        q("Error: 'I want check in.' — ভুল?", ["I want", "check in", "—", "—"], 1, "'Check in' noun/gerund? 'I want to check in.' বা 'I'd like to check in.' হবে।"),
        q("Error: 'I have a reservation for name of Rahman.' — ভুল?", ["I have a reservation", "for name of", "Rahman", "—"], 1, "'I have a reservation under the name of Rahman.' — 'under the name of' হবে।"),
        q("Error: 'Can I check out late?' — সঠিক?", ["সঠিক", "'May I' বেশি formal", "দুটোই", "—"], 0, "'Can I check out late?' — চলে (informal)। Formal = 'May I check out late?'"),
        q("Error: 'I need to cancel my booking.' — সঠিক?", ["সঠিক", "'Cancel my reservation' বেশি formal", "দুটোই সঠিক", "—"], 2, "'Cancel my booking/reservation' — দুটোই সঠিক।"),
        q("Fill: 'I'd like to ___ a double room.'", ["book", "take", "keep", "have"], 0, "'Book/Reserve a room' — রুম বুক করা।"),
        q("Fill: 'How much is it ___ night?'", ["per", "for", "in", "by"], 0, "'Per night' = প্রতি রাতে।"),
        q("Fill: 'The flight has been ___ (বিলম্বিত).'", ["delayed", "canceled", "booked", "checked"], 0, "'Delayed' = বিলম্বিত। 'The flight has been delayed.'"),
        q("Fill: 'What is the ___ (গেট) number?'", ["gate", "door", "entrance", "exit"], 0, "'Gate number' = বিমান ওঠার গেট।"),
        q("অনুবাদ: 'আমার কি একটি সিঙ্গেল রুম আছে?'", ["I want single room.", "Do you have a single room available?", "Single room please.", "Give single room."], 1, "'Do you have a single room available?' = polite inquiry।"),
        q("অনুবাদ: 'আমার ফ্লাইট কখন ছাড়বে?'", ["When my flight leave?", "When does my flight depart?", "My flight depart when?", "When my flight will go?"], 1, "'When does my flight depart?' = সঠিক interrogative structure।")
    ]
}

# 60: Telephone Conversations
ALL["mock_test_60"] = {
    "id": "mock_test_60", "testNumber": 60,
    "title": "Mock Test 60 - Telephone Conversations",
    "description": "Telephone Conversation নিয়ে ২০টি প্রশ্ন। ফোনে নিজের পরিচয় দেওয়া, message রাখা/নেওয়া, call transfer, appointment scheduling, problem explaining — প্রয়োজনীয় phrase।",
    "questions": [
        q("ফোন ধরে নিজের পরিচয় দেওয়ার সঠিক উপায়?", ["Hello, I am Rahim.", "Hello, this is Rahim speaking.", "Hello, Rahim here.", "Hello, it's Rahim."], 1, "'This is...speaking' = formal phone self-introduction। 'This is Rahim speaking.'"),
        q("কাউকে ফোনে চাইলে কী বলবেন?", ["I want Rahim.", "Could I speak to Rahim, please?", "Rahim here?", "Give me Rahim."], 1, "'Could I speak to...please?' = polite phone request।"),
        q("ভুল নাম্বারে কল করলে কী বলবেন?", ["Wrong number!", "I'm sorry, I think I have the wrong number.", "You wrong.", "Mistake."], 1, "'I'm sorry, I think I have the wrong number.' = polite apology।"),
        q("কেউ কে জিজ্ঞেস করলে 'Who's calling?' — এর উত্তর কী?", ["I am Rahim.", "This is Rahim.", "It's Rahim.", "Rahim is here."], 1, "'This is Rahim.' বা 'This is Rahim calling.' = সঠিক উত্তর।"),
        q("কাউকে Hold-এ রাখতে চাইলে কী বলবেন?", ["Wait.", "Please hold the line. I'll connect you.", "Stop.", "Don't go."], 1, "'Please hold the line.' বা 'Can you hold, please?' = polite hold request।"),
        q("Message নেওয়ার সঠিক উপায়?", ["Can I take a message?", "Tell me message.", "Write message here.", "Say message."], 0, "'Can I take a message?' / 'Would you like to leave a message?' = polite।"),
        q("Call transfer করার সঠিক বাক্য?", ["I'm transferring you to the department.", "Go to other phone.", "Talk to him.", "Call other."], 0, "'I'm transferring you to...' বা 'I'll put you through to...' = transfer phrase।"),
        q("'I'll call you back later.' — এর অর্থ কী?", ["আমি পরে কল করব", "আমি কল কেটে দিচ্ছি", "আমি কল রিসিভ করছি", "আমি এখন কল করছি"], 0, "'Call back' = আবার কল করা। 'I'll call you back later.'"),
        q("কেউ absent থাকলে কী বলবেন?", ["He is not here.", "I'm sorry, he's not available at the moment.", "He is gone.", "He not present."], 1, "'He's not available at the moment.' = polite way to say someone is absent।"),
        q("Appointment scheduling করার সঠিক উপায়?", ["I want to fix an appointment.", "I'd like to schedule an appointment.", "I need appointment.", "Appointment book."], 1, "'I'd like to schedule an appointment for...' = polite appointment request।"),
        q("Error: 'I want to talk with Rahim.' — ফোনে আরও polite variant কী?", ["I want", "to talk with", "Rahim", "—"], 0, "'I want' → 'Could I speak to Rahim, please?' বেশি polite।"),
        q("Error: 'Who is on the phone?' — সঠিক?", ["সঠিক", "'Who is calling?' হবে", "ভুল", "—"], 1, "'Who is calling?' বা 'May I ask who's calling?' — বেশি polite এবং phone-appropriate।"),
        q("Error: 'Please tell him that I called.' — সঠিক?", ["সঠিক", "'Please tell him I called.' হবে", "'that' unnecessary", "—"], 0, "'Please tell him that I called.' — 'that' optional, বাক্যটি সঠিক।"),
        q("Error: 'I will ring you off.' — সঠিক phrasal verb?", ["ring off", "ring up", "hang up", "call off"], 2, "'Hang up' = কল কেটে দেওয়া (telephone)। 'Ring off' = BrE but less common। 'Hang up' বেশি common।"),
        q("Fill: 'Could I ___ (speak) to Mr. Rahman?'", ["speak", "speaking", "spoken", "speaks"], 0, "'Could I speak to...?' — Modals এর পরে V1 (base form)।"),
        q("Fill: 'I'm sorry, he's ___ (বাইরে) at the moment.'", ["out", "outside", "out of office", "away"], 0, "'He's out' = he's not in the office (most common)।"),
        q("Fill: 'I'll ___ (যোগাযোগ) you by email.'", ["contact", "call", "connect", "reach"], 0, "'Contact you by email' = ইমেইলে যোগাযোগ করা।"),
        q("Fill: 'Could you ___ (পুনরাবৃত্তি) that, please?'", ["repeat", "say again", "tell again", "reply"], 0, "'Could you repeat that, please?' = polite way to ask for repetition।"),
        q("অনুবাদ: 'আমি কি রহিমের সাথে কথা বলতে পারি?'", ["Can I speak Rahim?", "Could I speak to Rahim, please?", "I want Rahim.", "Tell Rahim."], 1, "'Could I speak to Rahim, please?' = polite phone request।"),
        q("অনুবাদ: 'তাকে বলবেন যে আমি ফোন দিয়েছিলাম?'", ["Tell him I called.", "Please tell him that I called.", "Say to him I call.", "Tell him I phone."], 1, "'Please tell him that I called.' = polite message request।")
    ]
}

# 61-70: Minimal but complete set per topic
q61 = [
    q("\"Tell me about yourself\" — এই প্রশ্নের উত্তর কীভাবে শুরু করবেন?", ["My name is... and I am...", "I am...", "I will...", "সবগুলোই সঠিক"], 0, "Tell me about yourself → 'My name is...I am from...' — structured introduction।"),
    q("'I am a quick learner.' — এটি interview-এ কী বোঝায়?", ["আমি তাড়াতাড়ি শিখি", "আমি ধীরে শিখি", "আমি পড়াই", "আমি লিখি"], 0, "'Quick learner' = someone who learns fast — positive quality।"),
    q("'What are your strengths?' — উত্তরে কী বলবেন?", ["I am hardworking and punctual.", "I have no strengths.", "I don't know.", "I am bad at work."], 0, "Strengths → positive qualities: hardworking, punctual, team player etc।"),
    q("'What are your weaknesses?' — উত্তরের সঠিক উপায়?", ["I have no weaknesses.", "I work too hard and sometimes I forget to take breaks.", "I am lazy.", "I don't know."], 1, "Weakeness বলার সময় একটি real weakness বলুন + how you manage it।"),
    q("'Why should we hire you?' — উত্তরের সঠিক উপায়?", ["I need job.", "I have the skills and experience you need.", "Because I am good.", "Hire me."], 1, "'I have the skills and experience required for this role.' = confident and relevant।"),
    q("'Where do you see yourself in 5 years?' — উত্তর?", ["I want to grow professionally in this company.", "I don't know.", "I will leave.", "I want money."], 0, "'I see myself growing in this organization' — ambitious and committed।"),
    q("'Thank you for the opportunity' — interview-এর শেষে এটি বলা কেমন?", ["Polite and professional", "Unnecessary", "Rude", "Too formal"], 0, "'Thank you for the opportunity to interview.' = polite closing।"),
    q("Salary expectation জিজ্ঞেস করলে কী বলবেন?", ["I expect 50000.", "I am open to negotiation based on the market rate.", "Give me maximum.", "I don't know."], 1, "'I am open to negotiation.' বা 'My expected range is...' = professional answer।"),
    q("'I look forward to hearing from you.' — এর অর্থ কী?", ["আমি তোমার কাছ থেকে শুনতে চাই", "আমি উত্তরের অপেক্ষায় থাকলাম", "আমি এখন শুনছি", "আমি বলছি"], 1, "'I look forward to hearing from you.' = formal closings in emails/interviews।"),
    q("'Do you have any questions for us?' — উত্তরে কী বলবেন?", ["Yes, what is the company culture like?", "Questions? No.", "No questions.", "I have no doubts."], 0, "Questions ask করা = interest দেখায়। 'What is the company culture like?' — ভালো question।"),
    q("Error: 'My name is Rahim and I am from Bangladesh.' — interview-এ সঠিক?", ["সঠিক introduction", "'I am from' → 'I come from' হবে", "'My name is' → 'Myself' হবে", "ভুল"], 0, "'My name is... I am from...' — standard and correct।"),
    q("Error: 'I am very interested for this job.' — ভুল?", ["I am", "interested for", "this job", "—"], 1, "'Interested in' (not 'for')। 'I am very interested in this job.'"),
    q("Error: 'I have one year experience.' — ভুল?", ["I have", "one year experience", "—", "—"], 1, "'One year of experience' - 'of' preposition needed। 'I have one year of experience.'"),
    q("Error: 'I will try my best for this job.' — বাক্যটি কেমন?", ["Acceptable", "'I will do my best' — standard phrase", "'Try my best' ভুল", "—"], 1, "'Do my best' বেশি common। 'I will do my best for the company.'"),
    q("Fill: 'I ___ from Dhaka University.'", ["graduated", "study", "am", "work"], 0, "'I graduated from...' — educational background বলার জন্য।"),
    q("Fill: 'I am ___ (আবেদনকারী) for this position.'", ["applicant", "applying", "applicator", "applicable"], 0, "'I am an applicant for this position.' বা 'I am applying for this position.'"),
    q("Fill: 'I have good ___ skills.'", ["communication", "communicate", "communicating", "communicative"], 0, "'Communication skills' = যোগাযোগ দক্ষতা — fixed phrase।"),
    q("Fill: 'I am comfortable working in a ___ environment.'", ["team", "teamwork", "teamworking", "team player"], 0, "'Team environment' = দলগত পরিবেশ।"),
    q("অনুবাদ: 'আমি এই চাকরির জন্য খুবই আগ্রহী।'", ["I am very interested in this job.", "I am very interested for this job.", "I very interest this job.", "I interesting this job."], 0, "'Interested in this job' — সঠিক preposition 'in'।"),
    q("অনুবাদ: 'আমার দুর্বলতা হল আমি নিখুঁত হতে চাই।' (Weakness হিসেবে)", ["My weakness is that I am lazy.", "My weakness is that I strive for perfection.", "My weakness is nothing.", "My weakness is sleeping."], 1, "'I strive for perfection' = weakness হিসেবে বলা যায় (আসল weakness নয় — strategic answer)।")
]
ALL["mock_test_61"] = {
    "id": "mock_test_61", "testNumber": 61,
    "title": "Mock Test 61 - Job Interview Questions",
    "description": "Job Interview নিয়ে ২০টি প্রশ্ন। Tell me about yourself, strengths/weaknesses, Why should we hire you, Do you have any questions — এবং interview vocabulary।",
    "questions": q61
}

# 62: Formal Email Writing
ALL["mock_test_62"] = {
    "id": "mock_test_62", "testNumber": 62,
    "title": "Mock Test 62 - Formal Email Writing",
    "description": "Formal Email Writing নিয়ে ২০টি প্রশ্ন। Subject line, Salutation, Body, Closing, Formal vocabulary, Polite request, Attachment, CC/BCC।",
    "questions": [
        q("Formal email-এর সঠিক subject line কোনটি?", ["Application for the post of Assistant Manager", "Job Application", "Hey, I want job", "Applying"], 0, "'Application for the post of...' = clear and formal subject line।"),
        q("Formal email-এ সঠিক salutation কোনটি?", ["Hey", "Hi", "Dear Mr. Rahman", "Hello"], 2, "'Dear Mr. Rahman' (যদি নাম জানা থাকে) — formal salutation।"),
        q("যদি recipient-এর নাম না জানেন, কী লিখবেন?", ["Dear Sir or Madam,", "To Whom It May Concern,", "Hello there,", "Hi, no name"], 0, "'Dear Sir or Madam' — standard formal salutation (name unknown)।"),
        q("Email body শুরু করার সঠিক উপায়?", ["I am writing to...", "I write to...", "This email is to...", "All are correct"], 0, "'I am writing to...' = most common formal email opening।"),
        q("কাউকে কিছু attach করলে কী লিখবেন?", ["Please find attached the document.", "I attached file.", "Here is file.", "Attachment here."], 0, "'Please find attached...' = formal way to mention attachment।"),
        q("Email-এ polite request করার উপায়?", ["I would be grateful if you could...", "Do it.", "I want you to...", "You have to..."], 0, "'I would be grateful if you could...' = polite request structure।"),
        q("Formal email-এর সঠিক closing কোনটি?", ["Yours sincerely,", "Later,", "Bye,", "Cheers,"], 0, "'Yours sincerely' (যদি নাম দিয়ে শুরু) / 'Yours faithfully' (Sir/Madam দিয়ে শুরু)।"),
        q("CC এবং BCC-এর মধ্যে পার্থক্য কী?", ["একই", "CC = সবাই দেখে, BCC = অন্যরা BCC দেখে না", "BCC = সবাই দেখে", "উল্টো"], 1, "CC (Carbon Copy) = all recipients see each other। BCC (Blind CC) = recipients don't see BCC-ers।"),
        q("'I look forward to your response.' — এটি email-এর কোন অংশে বসে?", ["Beginning", "Middle", "Closing (আশা প্রকাশ)", "Subject"], 2, "'I look forward to hearing from you.' = closing-এ আশা প্রকাশ।"),
        q("'Please do not hesitate to contact me.' — এটি কী ধরনের phrase?", ["Formal and polite", "Informal", "Rude", "Unprofessional"], 0, "'Please do not hesitate to contact me.' = formal and polite offer for further contact।"),
        q("Error: 'Dear Sir, I am writing to apply for the job.' — এখানে 'the job' কীভাবে বলা ভালো?", ["the job → this position/the post", "the job ঠিক আছে", "'the job' formal না", "—"], 0, "'The post' বা 'the position' — 'the job' generic, 'the post' বেশি formal।"),
        q("Error: 'I want to apply for this job.' → আরও formal variant?", ["ছোট করে বলুন", "I would like to apply for this position.", "উভয়ই formal", "—"], 1, "'I would like to apply...' = more formal than 'I want to apply...'"),
        q("Error: 'Thanks in advance.' — formal email-এ এটি কেমন?", ["Acceptable but caution needed", "'Thank you in advance' — mild presumption", "Unprofessional", "—"], 1, "'Thank you in advance' — formal কিন্তু কিছুটা presumptuous (আগেই ধন্যবাদ)। 'I would appreciate your help.' বেশি polite।"),
        q("Error: 'I am attaching my CV herewith.' — সঠিক?", ["'Herewith' dated/formal", "'Herewith' → 'with this email'", "'Herewith' ঠিক আছে", "—"], 2, "'Please find attached my CV.' = more modern and common। 'Herewith' = very old-fashioned but not incorrect।"),
        q("Fill: 'I am writing ___ apply for the post.'", ["to", "for", "in", "at"], 0, "'To apply' — Infinitive of purpose।"),
        q("Fill: 'I have attached my resume for your ___ (বিবেচনা).'", ["consideration", "reference", "view", "seeing"], 0, "'For your consideration' = formal। 'For your reference' = your review।"),
        q("Fill: 'Please feel ___ to contact me.'", ["free", "welcome", "open", "available"], 0, "'Please feel free to contact me.' = formal invitation for further communication।"),
        q("Fill: 'I ___ forward to your response.'", ["look", "am looking", "looked", "will look"], 0, "'I look forward to + noun/gerund' — formal fixed phrase।"),
        q("অনুবাদ: 'আমি আবেদনপত্রের সাথে আমার সিভি সংযুক্ত করছি।'", ["I am attaching my CV with the application.", "Please find attached my CV with the application.", "I attached my CV.", "CV is here."], 1, "'Please find attached my CV with the application.' = formal and correct।"),
        q("অনুবাদ: 'আপনার দ্রুত সাড়া পেয়ে আমি কৃতজ্ঞ হব।'", ["I will be grateful for your early response.", "I would be grateful for your prompt response.", "Reply soon please.", "I'm waiting."], 1, "'I would be grateful for your prompt response.' = formal and polite।")
    ]
}

# 63: Opinion & Discussion
ALL["mock_test_63"] = {
    "id": "mock_test_63", "testNumber": 63,
    "title": "Mock Test 63 - Opinion & Discussion",
    "description": "Opinion ও Discussion Expression নিয়ে ২০টি প্রশ্ন। In my opinion, I believe, From my point of view, As far as I'm concerned, It seems to me, I strongly feel — সঠিক ব্যবহার।",
    "questions": [
        q("'In my opinion' phrase-টির ব্যবহার কী?", ["মতামত প্রকাশ করা", "তথ্য দেওয়া", "প্রশ্ন করা", "আদেশ দেওয়া"], 0, "'In my opinion' = নিজের মতামত প্রকাশ করার formal phrase।"),
        q("'I believe that...' — এটি কী বোঝায়?", ["আমি জানি", "আমি বিশ্বাস করি (মতামত)", "আমি নিশ্চিত", "আমি করি"], 1, "'I believe that...' = personal belief/opinion প্রকাশ করে।"),
        q("'From my perspective' — এটি কী প্রকাশ করে?", ["তথ্য", "দৃষ্টিকোণ থেকে মতামত", "প্রশ্ন", "আদেশ"], 1, "'From my perspective' = আমার দৃষ্টিকোণ থেকে। 'My perspective' = my point of view।"),
        q("'As far as I'm concerned' — এর অর্থ কী?", ["যতদূর আমি জানি", "আমার মতে / আমার দৃষ্টিতে", "যদি আমি জানতাম", "আমি যতদূর পারি"], 1, "'As far as I'm concerned' = as for me / in my opinion।"),
        q("'It seems to me that...' — এটি কী বোঝায়?", ["নিশ্চিত সত্য", "আমার ধারণা (certain নয়)", "প্রশ্ন", "আদেশ"], 1, "'It seems to me' = appears to be/আমার মনে হয় (opinion with less certainty)।"),
        q("Which is the most formal opinion phrase?", ["I think", "In my opinion", "I guess", "I feel"], 1, "'In my opinion' (formal) > 'I think' (neutral) > 'I guess' (informal) > 'I feel' (personal)"),
        q("'I strongly believe that...' — 'strongly' যোগ করার অর্থ কী?", ["মতামত জোরালো করা", "মতামত দুর্বল করা", "প্রশ্ন করা", "নিশ্চিত হওয়া"], 0, "'Strongly believe' = জোরালো মতামত প্রকাশ (I firmly believe)"),
        q("'I am convinced that...' — এর অর্থ কী?", ["আমি সন্দেহ করি", "আমি নিশ্চিত (convinced)", "আমি জানি না", "আমি ভাবি"], 1, "'I am convinced that...' = I believe strongly (নিশ্চিতভাবে বিশ্বাস)"),
        q("অন্যের opinion চাইতে কী বলবেন?", ["What do you think?", "Tell your opinion.", "You think what?", "Opinion please."], 0, "'What do you think?' / 'What is your opinion on this?' = polite opinion inquiry।"),
        q("'I see your point, but...' — এটি কী বোঝায়?", ["সম্পূর্ণ অসম্মতি", "আংশিক সম্মতির পর অসম্মতি", "সম্পূর্ণ সম্মতি", "কোনো মন্তব্য নেই"], 1, "'I see your point, but...' = I partly agree, but I have a different view।"),
        q("Error: 'In my opinion, I think that...' — সমস্যা?", ["Redundant (দুটো phrase একই অর্থ)", "'In my opinion' বা 'I think' — একটি যথেষ্ট", "ভুল না, কিন্তু repetitive", "সবগুলো"], 2, "'In my opinion' এবং 'I think' একই অর্থ → একটিই যথেষ্ট।"),
        q("Error: 'From my point of view, I believe that...' — সমস্যা?", ["একটু formal কিন্তু গ্রহণযোগ্য", "'From my point of view' + 'I believe' = redundant", "ভুল", "—"], 1, "'From my point of view' এবং 'I believe' → একটিই যথেষ্ট।"),
        q("Error: 'As far as I'm concerned, I don't think this is correct.' — সঠিক?", ["সঠিক", "Double negative?", "'Don't think is correct' → 'think this is incorrect' ভালো", "ভুল"], 0, "গঠনগতভাবে সঠিক। কিন্তু 'I think this is incorrect' বেশি direct।"),
        q("Error: 'I am agree with you.' — ভুল?", ["I am agree", "with you", "—", "—"], 0, "'I agree with you.' — 'agree' verb, এর সাথে 'am' লাগে না।"),
        q("Fill: '___ my opinion, this plan is good.'", ["In", "To", "From", "By"], 0, "'In my opinion' — fixed preposition 'in'।"),
        q("Fill: 'What is your ___ (মতামত) on this issue?'", ["opinion", "thought", "view", "সবগুলোই"], 3, "'Opinion / thought / view' — সবগুলোই সঠিক।"),
        q("Fill: 'I ___ that we should try again.'", ["think", "believe", "feel", "সবগুলোই"], 3, "'I think/believe/feel' — সবগুলোই মতামত প্রকাশ করে।"),
        q("Fill: '___ far as I'm concerned, it's a good idea.'", ["As", "So", "By", "For"], 0, "'As far as I'm concerned' — fixed phrase।"),
        q("অনুবাদ: 'আমার মতে, ইংরেজি শেখা খুব গুরুত্বপূর্ণ।'", ["In my opinion, learning English is very important.", "I think learning English is important.", "To me, English is important.", "সবগুলোই সঠিক"], 3, "সব কয়টি variant সঠিক এবং natural।"),
        q("অনুবাদ: 'আমি দৃঢ়ভাবে বিশ্বাস করি যে শিক্ষা অপরিহার্য।'", ["I strongly believe that education is essential.", "I think education is essential.", "Education is important.", "Strongly I believe education essential."], 0, "'I strongly believe that...' = জোরালো মতামত প্রকাশ।")
    ]
}

# 64: Agreeing & Disagreeing
ALL["mock_test_64"] = {
    "id": "mock_test_64", "testNumber": 64,
    "title": "Mock Test 64 - Agreeing & Disagreeing",
    "description": "Agreeing ও Disagreeing Expression নিয়ে ২০টি প্রশ্ন। I agree, I disagree, I'm afraid I disagree, You're right, That's true, I see your point but, I'm not sure about that — সঠিক ব্যবহার।",
    "questions": [
        q("সম্পূর্ণ সম্মতি জানানোর সঠিক phrase?", ["I completely agree.", "I agree with you.", "You're right.", "That's true.",], 0, "'I completely/absolutely agree.' = strong agreement।"),
        q("বিনয়ের সাথে অসম্মতি জানানোর উপায়?", ["I'm afraid I disagree.", "You are wrong.", "No.", "Not correct."], 0, "'I'm afraid I disagree.' = polite disagreement। 'I'm afraid = দুঃখিত।"),
        q("'I see your point, but...' — এটি কী বোঝায়?", ["সম্পূর্ণ অসম্মতি", "Partial agreement + different view", "কোনো মন্তব্য নেই", "সম্পূর্ণ সম্মতি"], 1, "'I see your point, but...' = I understand but I have a different opinion।"),
        q("'That's a good point.' — এটি কী বোঝায়?", ["অসম্মতি", "অন্যের argument স্বীকার করা/সমর্থন", "প্রশ্ন", "আদেশ"], 1, "'That's a good point.' = I acknowledge/accept your argument as valid।"),
        q("'I couldn't agree more.' — এর অর্থ কী?", ["আমি একটুও একমত নই", "আমি পুরোপুরি একমত (cannot agree more)", "আমি কিছু বলতে পারছি না", "আমি শুধু শুনছি"], 1, "'I couldn't agree more.' = I completely agree (আমি এর চেয়ে বেশি একমত হতে পারি না = পুরোপুরি একমত)।"),
        q("'I'm not sure about that.' — এটি কী ধরনের উত্তর?", ["Polite doubt/disagreement", "Strong agreement", "Full confidence", "Ignorance"], 0, "'I'm not sure about that.' = polite/soft disagreement or doubt।"),
        q("'You have a point there.' — এর অর্থ কী?", ["তোমার একটা point ঠিক আছে", "তুমি ভুল", "আমি সঠিক", "কিছুই না"], 0, "'You have a point there.' = I agree partly/আপনার যুক্তি গ্রহণযোগ্য।"),
        q("'I beg to differ.' — এটি কী ধরনের expression?", ["Formal disagreement", "Informal agreement", "Question", "Sorry"], 0, "'I beg to differ.' = formal way to say 'I disagree'।"),
        q("'That's exactly what I think.' — এটি কী বোঝায়?", ["সম্পূর্ণ অসম্মতি", "সম্পূর্ণ সম্মতি", "সন্দেহ", "অজ্ঞতা"], 1, "'That's exactly what I think.' = strong agreement / exactly my opinion।"),
        q("'We are on the same page.' — এর অর্থ কী?", ["আমরা একমত", "আমরা ভিন্ন পৃষ্ঠায় আছি", "আমরা পড়ছি", "আমরা লিখছি"], 0, "'We are on the same page.' = we agree / share the same understanding।"),
        q("Error: 'I am agree with you.' — ভুল?", ["I am agree", "with you", "—", "—"], 0, "'I agree with you.' — 'agree' verb, 'am' লাগে না।"),
        q("Error: 'I don't agree you.' — ভুল?", ["I don't agree", "you", "—", "—"], 1, "'I don't agree with you.' — 'agree' এর পরে 'with' needed।"),
        q("Error: 'According to me, this is wrong.' — গ্রহণযোগ্য?", ["'In my opinion' বা 'To me' বেশি common", "'According to me' is less natural", "ভুল না, কিন্তু in my opinion ভালো", "সবগুলো"], 2, "'According to me' — some argue it's incorrect; 'In my opinion' বেশি natural এবং grammatically accepted।"),
        q("Error: 'I totally disagree. You are completely wrong.' — কেমন?", ["Direct/rude", "Polite", "Formal", "Soft"], 0, "'You are completely wrong' = very direct and could be rude। 'I'm afraid I disagree' — বেশি polite।"),
        q("Fill: 'I completely ___ with your opinion.'", ["agree", "disagree", "concur", "সবগুলো"], 3, "'I completely agree/disagree/concur' — সবগুলোই সঠিক verb।"),
        q("Fill: 'I'm afraid I have to ___ (অসম্মতি জানাই).'", ["disagree", "agree", "say", "tell"], 0, "'I'm afraid I have to disagree.' — polite disagreement।"),
        q("Fill: 'You've ___ a very good point.'", ["made", "said", "told", "given"], 0, "'Make a point' — 'You've made a very good point.'"),
        q("Fill: 'I couldn't ___ more. You're absolutely right.'", ["agree", "disagree", "say", "think"], 0, "'I couldn't agree more.' = I completely agree।"),
        q("অনুবাদ: 'আমি আপনার সাথে একমত।'", ["I am agree with you.", "I agree with you.", "I agreeing with you.", "I agreed with you."], 1, "'I agree with you.' — Present Indefinite, 'am' লাগে না।"),
        q("অনুবাদ: 'আমি দুঃখিত, আমি আপনার সাথে একমত নই।' (polite)", ["I disagree.", "I am sorry, I don't agree.", "I'm afraid I disagree with you.", "Not agree."], 2, "'I'm afraid I disagree with you.' = most polite।")
    ]
}

# 65: Apologizing & Thanking
ALL["mock_test_65"] = {
    "id": "mock_test_65", "testNumber": 65,
    "title": "Mock Test 65 - Apologizing & Thanking",
    "description": "Apologizing ও Thanking Expression নিয়ে ২০টি প্রশ্ন। I'm sorry, I apologize, Please forgive me, Thank you, Thanks a lot, I appreciate it, You're welcome, Don't mention it — সঠিক ব্যবহার।",
    "questions": [
        q("ক্ষমা চাওয়ার সবচেয়ে সাধারণ উপায় কী?", ["I'm sorry.", "I apologize.", "Forgive me.", "Excuse me."], 0, "'I'm sorry' = সবচেয়ে common apology। 'I apologize' = more formal।"),
        q("Formal apology-এর সঠিক phrase কোনটি?", ["I apologize for the inconvenience.", "Sorry.", "My bad.", "Oops."], 0, "'I apologize for the inconvenience.' = formal apology।"),
        q("'Please accept my apologies.' — এটি কী বোঝাচ্ছে?", ["ক্ষমা প্রার্থনা (formal)", "ধন্যবাদ", "অনুরোধ", "আদেশ"], 0, "'Please accept my apologies.' = formal apology (written/spoken)।"),
        q("কারো ক্ষমা গ্রহণের সঠিক উপায়?", ["That's okay.", "Don't worry about it.", "It's fine.", "সবগুলোই"], 3, "'That's okay / Don't worry / It's fine' — সবগুলোই polite acceptance of apology।"),
        q("ধন্যবাদ জানানোর formal উপায়?", ["Thank you very much.", "I am grateful.", "Thanks.", "Cheers."], 0, "'Thank you very much.' = formal। 'I am grateful' = even more formal।"),
        q("ধন্যবাদ দেওয়ার উত্তরে কী বলবেন?", ["You're welcome.", "My pleasure.", "Not at all.", "সবগুলোই"], 3, "'You're welcome / My pleasure / Not at all' — সবগুলোই correct response।"),
        q("'I appreciate your help.' — এটি কী বোঝায়?", ["আমি তোমার সাহায্যের প্রশংসা করি", "আমি সাহায্য চাই", "আমি সাহায্য করি", "আমি চাই না"], 0, "'I appreciate your help.' = I am grateful for your help (formal thank you)।"),
        q("'Don't mention it.' — কখন ব্যবহার করবেন?", ["কেউ ধন্যবাদ দিলে উত্তরে", "ক্ষমা চাইলে", "প্রশ্ন করলে", "আদেশ দিলে"], 0, "'Don't mention it.' = polite reply to 'Thank you' — meaning 'it was nothing'।"),
        q("ছোটখাটো ভুলের জন্য casual apology?", ["My bad.", "Oops, sorry.", "I apologize.", "Forgive me."], 1, "'Oops, sorry.' = casual minor mistake-এর জন্য। 'My bad' = informal/young generation।"),
        q("'I owe you an apology.' — এর অর্থ কী?", ["আমি তোমার কাছে ক্ষমাপ্রার্থী", "আমি তোমাকে টাকা দেব", "আমি তোমাকে ধন্যবাদ দেব", "আমি তোমাকে সাহায্য করব"], 0, "'I owe you an apology.' = I should apologize to you (আমার ক্ষমা চাওয়া উচিত)।"),
        q("Error: 'I am sorry for late.' — ভুল?", ["I am sorry", "for late", "—", "—"], 1, "'I am sorry for being late / for the delay.' — 'for late' incomplete।"),
        q("Error: 'Thank you for you help.' — ভুল?", ["Thank you", "for you help", "—", "—"], 1, "'Thank you for your help.' — 'your' possessive adjective needed।"),
        q("Error: 'Please excuse my late.' — ভুল?", ["Please excuse", "my late", "—", "—"], 1, "'Please excuse my lateness / my being late.' — 'late' adjective, noun form needed।"),
        q("Error: 'I am very sorry for the trouble I have cause.' — ভুল?", ["I am", "the trouble", "I have cause", "—"], 2, "'I have caused' — Past Participle (caused) needed।"),
        q("Fill: 'I ___ for being late.'", ["apologize", "sorry", "apology", "apologetic"], 0, "'I apologize' (verb) — 'I am sorry' (adj) — 'I offer my apology' (noun)।"),
        q("Fill: '___ you very much for your kindness.'", ["Thank", "Thanks", "Thanking", "Thanked"], 0, "'Thank you very much.' — 'Thank' is a verb here।"),
        q("Fill: 'I would like to ___ my sincere gratitude.'", ["express", "say", "tell", "give"], 0, "'Express my gratitude' = formal thanks।"),
        q("Fill: 'Please ___ my sincere apologies.'", ["accept", "receive", "take", "get"], 0, "'Please accept my apologies.' — formal apology।"),
        q("অনুবাদ: 'বিলম্বের জন্য আমি দুঃখিত।'", ["I am sorry for late.", "I am sorry for the delay.", "Sorry late.", "Delay sorry."], 1, "'I am sorry for the delay.' — সঠিক formal apology।"),
        q("অনুবাদ: 'আপনার সাহায্যের জন্য আমি কৃতজ্ঞ।'", ["Thank you for help.", "I am grateful for your help.", "Thanks your help.", "Help thanks."], 1, "'I am grateful for your help.' — formal and correct।")
    ]
}

# 66: Making Requests & Offers
ALL["mock_test_66"] = {
    "id": "mock_test_66", "testNumber": 66,
    "title": "Mock Test 66 - Making Requests & Offers",
    "description": "Requests ও Offers Expression নিয়ে ২০টি প্রশ্ন। Could you please, Would you mind, Can I, Shall I, Would you like, I'd like to, Let me, Do you mind if — সঠিক ব্যবহার।",
    "questions": [
        q("Polite request করার সবচেয়ে ভালো উপায়?", ["Could you please help me?", "Help me.", "I want help.", "You help me."], 0, "'Could you please...?' = one of the most polite request forms।"),
        q("'Would you mind...?' দিয়ে request করার সঠিক structure?", ["Would you mind + Ving?", "Would you mind + to V1?", "Would you mind + V1?", "Would you mind + V3?"], 0, "'Would you mind + Ving' — যেমন: Would you mind opening the door?"),
        q("অনুমতি চাওয়ার সঠিক উপায়?", ["Can I use your phone?", "May I use your phone?", "Is it okay if I use your phone?", "সবগুলোই"], 3, "'Can I/May I/Do you mind if I' — সবগুলোই permission চাওয়ার জন্য।"),
        q("কাউকে কিছু offer করার সঠিক উপায়?", ["Would you like some tea?", "I want to give you tea.", "Take tea.", "Tea?"], 0, "'Would you like some tea?' = polite offer।"),
        q("'Shall I open the window?' — এটি কী বোঝায়?", ["অনুরোধ", "Offer (আমি কি খুলব?)", "আদেশ", "প্রশ্ন"], 1, "'Shall I...?' = offer to do something for someone।"),
        q("'I'd like to suggest something.' — এটি কী ধরনের phrase?", ["Polite suggestion/offer", "Rude order", "Question", "Apology"], 0, "'I'd like to...' = polite way to offer a suggestion।"),
        q("'Do you mind if I sit here?' — এর সঠিক উত্তর কী?", ["Yes (if you don't mind), No (if you mind)", "No=you can sit, Yes=don't sit", "প্যাঁচালো", "—"], 1, "'Do you mind if I sit here?' → 'No, go ahead.' (না আমি কিছু মনে করি না) বা 'Yes, I'm sorry.' (হ্যাঁ আমি মনে করি = বসতে দেব না)।"),
        q("'Let me help you.' — এটি কী ধরনের expression?", ["Request", "Order", "Offer to help", "Question"], 2, "'Let me help you.' = offer of assistance (volunteering to help)।"),
        q("'I was wondering if you could help me.' — এটি কেমন?", ["Very polite request", "Direct order", "Informal", "Rude"], 0, "'I was wondering if...' = indirect/very polite request।"),
        q("অফার decline করার সঠিক উপায়?", ["No, thank you.", "I'm fine, thanks.", "Not now, thanks.", "সবগুলোই"], 3, "'No, thank you.' / 'I'm fine, thanks.' — সবগুলোই polite refusal।"),
        q("Error: 'Can you please to help me?' — ভুল?", ["Can you", "please to help", "me", "—"], 1, "'Can you please help me?' — 'to' লাগবে না। Modal (can) + V1 (help)"),
        q("Error: 'Would you mind to open the door?' — ভুল?", ["Would you mind", "to open", "the door", "—"], 1, "'Would you mind opening the door?' — 'mind + Ving' (not 'to V1')।"),
        q("Error: 'I want that you help me.' — ভুল?", ["I want", "that you help me", "—", "—"], 1, "'I want you to help me.' — 'want + object + to V1' structure।"),
        q("Error: 'Let me to go.' — ভুল?", ["Let me", "to go", "—", "—"], 1, "'Let me go.' — 'let + object + V1' (to ছাড়া)।"),
        q("Fill: 'Would you like me ___ (help) you?'", ["help", "to help", "helping", "helped"], 1, "'Would you like me to help you?' — 'would like + object + to V1'।"),
        q("Fill: 'Could you please ___ (send) me the details?'", ["send", "to send", "sending", "sent"], 0, "'Could you please + V1 (send)' — modal এর পরে base form।"),
        q("Fill: 'I would ___ if you could help.'", ["appreciate it", "like", "want", "love"], 0, "'I would appreciate it if you could...' = polite request।"),
        q("Fill: '___ I get you a glass of water?'", ["Can", "Shall", "May", "Will"], 1, "'Shall I...?' = offer to do something (BrE common)।"),
        q("অনুবাদ: 'আপনি কি দরজাটা খুলে দেবেন?' (polite)", ["Open the door.", "Could you please open the door?", "You open door.", "Open door please."], 1, "'Could you please open the door?' = polite request।"),
        q("অনুবাদ: 'আমি কি আপনার কলমটি ব্যবহার করতে পারি?'", ["Can I use your pen?", "I want your pen.", "Give me pen.", "Use pen."], 0, "'Can I use your pen?' / 'May I use your pen?' = polite permission request।")
    ]
}

# 67: Describing People & Places
ALL["mock_test_67"] = {
    "id": "mock_test_67", "testNumber": 67,
    "title": "Mock Test 67 - Describing People & Places",
    "description": "People ও Places বর্ণনার Vocabulary নিয়ে ২০টি প্রশ্ন। Appearance, Personality, Places — There is/are, It has/It's known for — correct describing vocabulary।",
    "questions": [
        q("কোনো ব্যক্তির উচ্চতা বর্ণনা করবেন কীভাবে?", ["He is tall.", "He has tall.", "He is height tall.", "He height is tall."], 0, "'He is tall.' = adjective after 'be' verb। 'He has a tall height.' also possible।"),
        q("কারো চুলের বর্ণনার সঠিক উপায়?", ["He has black hair.", "He is black hair.", "His hair black.", "He have black hair."], 0, "'He has + (adjective) hair' — 'He has black/ long/ curly hair.'"),
        q("কারো চোখের বর্ণনা করবেন কীভাবে?", ["She has blue eyes.", "She is blue eyes.", "Her eyes is blue.", "She have blue eyes."], 0, "'She has + (color) eyes' — 'She has blue eyes.'"),
        q("ব্যক্তিত্বের বৈশিষ্ট্য বর্ণনা করবেন কীভাবে?", ["She is very kind.", "She has kindness.", "She kindness.", "She is kindness."], 0, "'She is + adjective (kind/honest/friendly).'"),
        q("কোনো জায়গার বর্ণনা দিতে 'There is/are' ব্যবহার করবেন কীভাবে?", ["There is a beautiful lake.", "There are a beautiful lake.", "The lake is there.", "There beautiful lake."], 0, "'There is + singular noun', 'There are + plural noun'।"),
        q("জায়গার অবস্থান বলার সঠিক উপায়?", ["It is located near the river.", "It located near river.", "It near the river.", "It is near to river."], 0, "'It is located in/on/near...' — 'is located' + preposition।"),
        q("'It is known for its beauty.' — এর অর্থ কী?", ["এটি তার সৌন্দর্যের জন্য বিখ্যাত", "এটি সৌন্দর্য জানে", "এটি সুন্দর হবে", "এটি সৌন্দর্য শেখে"], 0, "'Known for' = জন্য বিখ্যাত।"),
        q("কোনো জায়গার পরিবেশ বর্ণনা করবেন কীভাবে?", ["It is peaceful and quiet.", "It has peace and quiet.", "It peace and quiet.", "It is peace."], 0, "'It is + adjective (peaceful/quiet/noisy/crowded)' বা 'It has + noun (peace/quiet)'"),
        q("'He is tall and slim.' — এটি কী ধরনের বর্ণনা?", ["Appearance (Physical)", "Personality", "Profession", "Education"], 0, "'Tall and slim' = physical appearance description।"),
        q("'She is outgoing and friendly.' — এটি কী ধরনের বর্ণনা?", ["Appearance", "Personality", "Height", "Weight"], 1, "'Outgoing and friendly' = personality traits।"),
        q("Error: 'He is a tall man with black hair.' — সঠিক?", ["সঠিক", "'with' ব্যবহার ভুল", "'a tall man' → 'a tall and black hair man'", "ভুল"], 0, "'He is a tall man with black hair.' = correct structure for describing।"),
        q("Error: 'She has long hairs.' — ভুল?", ["She has", "long hairs", "—", "—"], 1, "'Hair' is uncountable (no 's')। 'She has long hair.'"),
        q("Error: 'He is a dark skin man.' — সঠিক?", ["'Dark-skinned' → hyphen + ed", "He is a dark skin man", "'Skin' not correct", "—"], 0, "'He is dark-skinned.' বা 'He has dark skin.' — adjective form = dark-skinned।"),
        q("Error: 'There is many parks in the city.' — ভুল?", ["There is", "many parks", "in the city", "—"], 0, "'Many parks' plural → 'There are many parks' হবে।"),
        q("Fill: 'She has ___ (কোঁকড়ানো) hair.'", ["curly", "straight", "long", "short"], 0, "'Curly hair' = কোঁকড়ানো চুল। 'Straight' = সোজা।"),
        q("Fill: 'He is very ___ (বন্ধুত্বপূর্ণ) and kind.'", ["friendly", "friendful", "friendless", "friendish"], 0, "'Friendly' = বন্ধুত্বপূর্ণ (adjective)।"),
        q("Fill: 'The city is ___ for its historical sites.'", ["famous", "known", "popular", "সবগুলোই"], 3, "'Famous/known/popular for' — সবগুলোই সঠিক।"),
        q("Fill: 'It is a ___ (শান্ত) place.'", ["peaceful", "peace", "peaceless", "peaceable"], 0, "'Peaceful' = শান্ত (adjective)। 'Peace' = noun।"),
        q("অনুবাদ: 'সে একজন লম্বা, সরু ও সুদর্শন লোক।'", ["He is tall, slim and handsome.", "He tall, slim, handsome.", "He is tall slim handsome.", "He is tall and slim and handsome."], 0, "'He is tall, slim and handsome.' — comma + 'and' — correct enumeration।"),
        q("অনুবাদ: 'ঢাকা তার জনসংখ্যার জন্য পরিচিত।'", ["Dhaka is known for its population.", "Dhaka knows its population.", "Dhaka is known by its population.", "Dhaka famous its population."], 0, "'Dhaka is known for its population.' — 'known for' = জন্য পরিচিত।")
    ]
}

# 68: Telling Stories / Past Narrative
ALL["mock_test_68"] = {
    "id": "mock_test_68", "testNumber": 68,
    "title": "Mock Test 68 - Telling Stories (Past Narrative)",
    "description": "Storytelling/Past Narrative নিয়ে ২০টি প্রশ্ন। Past tenses, Sequence words (First, Then, After that, Finally), Time expressions (Suddenly, Eventually, In the end) — সঠিক ব্যবহার।",
    "questions": [
        q("Storytelling-এ সবচেয়ে বেশি কোন tense ব্যবহার হয়?", ["Present Indefinite", "Past Indefinite (Simple Past)", "Future Indefinite", "Present Continuous"], 1, "Past Indefinite (Simple Past) is the main tense for storytelling।"),
        q("গল্পের শুরুতে কোন শব্দ ব্যবহার করা হয়?", ["Once upon a time...", "First...", "Long ago...", "সবগুলোই"], 3, "'Once upon a time / First / Long ago / In the beginning' — সবগুলোই story শুরুতে।"),
        q("ঘটনার ক্রম বোঝাতে কোন sequence word ব্যবহার করা হয়?", ["First", "Then", "After that", "Finally", "সবগুলোই"], 4, "'First, Then, After that, Finally' — সবগুলোই events sequence বোঝায়।"),
        q("হঠাৎ কোনো ঘটনা বোঝাতে কোন word ব্যবহার করা হয়?", ["Suddenly", "Gradually", "Always", "Never"], 0, "'Suddenly' = unexpected event বোঝাতে।"),
        q("গল্পের শেষ বোঝাতে কোন phrase ব্যবহার করা হয়?", ["In the end", "Finally", "Eventually", "সবগুলোই"], 3, "'In the end / Finally / Eventually' — সবগুলোই ending বোঝায়।"),
        q("Past Continuous (was/were + Ving) কখন ব্যবহার হয়?", ["সম্পূর্ণ অতীত কাজ", "অতীতে চলমান কাজ (background action)", "বর্তমান কাজ", "ভবিষ্যৎ কাজ"], 1, "Past Continuous = ongoing action in the past (background)। যেমন: I was walking when it rained।"),
        q("Past Perfect (had + V3) কখন ব্যবহার হয়?", ["দুটি past event-এর মধ্যে আগেরটি বোঝাতে", "পরেরটি বোঝাতে", "বর্তমান কাজ", "ভবিষ্যৎ কাজ"], 0, "Past Perfect = earlier of two past events। 'I had eaten before he arrived.'"),
        q("'While I was sleeping, the phone rang.' — এখানে 'While' কী বোঝাচ্ছে?", ["দুটি ঘটনা একসাথে", "ঘটনার ক্রম", "কারণ", "শর্ত"], 0, "'While + past continuous' = something happened during an ongoing action।"),
        q("'First, we went to Cox's Bazar. Then, we visited Saint Martin.' — 'Then' কী বোঝাচ্ছে?", ["একই সময়", "পরবর্তী ঘটনা", "কারণ", "শর্ত"], 1, "'Then' = next event in sequence।"),
        q("'It was a dark and stormy night.' — এটি গল্পের কোন অংশ?", ["মধ্য", "শুরু (setting the scene)", "শেষ", "কোনটাই না"], 1, "'It was a dark and stormy night.' = scene-setting opening line (famous story opening)।"),
        q("Error: 'Yesterday I go to the market.' — ভুল?", ["Yesterday", "go", "to the market", "—"], 1, "'Yesterday' → Past needed: 'I went to the market.'"),
        q("Error: 'I was walk when it started raining.' — ভুল?", ["I was walk", "when", "it started raining", "—"], 0, "'I was walking' — Past Continuous: was/were + Ving।"),
        q("Error: 'After I had ate dinner, I went out.' — ভুল?", ["After", "I had ate", "dinner", "I went out"], 1, "'Had + V3' → 'had eaten' (ate → eaten)।"),
        q("Error: 'He was going to market when he was meeting his friend.' — ভুল?", ["was going", "when he was meeting", "—", "—"], 1, "'When' + Simple Past (met) for short action। 'When he met his friend.'"),
        q("Fill: 'First, we ___ (reach) the station. Then, we bought tickets.'", ["reached", "reach", "had reached", "were reaching"], 0, "Simple Past for completed actions in sequence: 'reached'।"),
        q("Fill: 'While I ___ (watch) TV, the light went out.'", ["watched", "was watching", "had watched", "am watching"], 1, "'While + past continuous (was watching)' for background action।"),
        q("Fill: 'She ___ (finish) her homework before she went to bed.'", ["finished", "had finished", "was finishing", "finishes"], 1, "'Before she went' → earlier action: 'had finished' (Past Perfect)।"),
        q("Fill: '___ (অবশেষে), they arrived at the destination.'", ["Finally", "At last", "Eventually", "সবগুলোই"], 3, "'Finally / At last / Eventually' — সবগুলোই 'অবশেষে' অর্থে।"),
        q("অনুবাদ: 'প্রথমে, আমরা নাস্তা করলাম। তারপর, আমরা বের হলাম।'", ["First we ate breakfast. Then we left.", "First we eat breakfast. Then we leave.", "First we had ate. Then left.", "First we were eating. Then we left."], 0, "'First...Then...' + Past Simple (ate, left) — sequence of past events।"),
        q("অনুবাদ: 'আমি যখন পড়ছিলাম, তখন আমার বন্ধু এলো।'", ["I read when my friend came.", "I was reading when my friend came.", "I am reading when friend came.", "I had read when friend came."], 1, "'Was reading (ongoing action) when friend came (short action)' = Past Continuous + Simple Past।")
    ]
}

# 69: Giving Directions
ALL["mock_test_69"] = {
    "id": "mock_test_69", "testNumber": 69,
    "title": "Mock Test 69 - Giving Directions",
    "description": "Direction দেওয়ার Expression নিয়ে ২০টি প্রশ্ন। Go straight, Turn left/right, Take the first/second turning, It's on the corner, It's opposite/near/next to — সঠিক ব্যবহার।",
    "questions": [
        q("সোজা যেতে বলার সঠিক phrase কী?", ["Go straight.", "Go direct.", "Go left.", "Go front."], 0, "'Go straight.' বা 'Go straight ahead.' = সোজা যান।"),
        q("বামে যেতে বলার সঠিক phrase কী?", ["Turn left.", "Go left.", "Take left.", "Left turn."], 0, "'Turn left.' = বামে ঘুরুন। 'Go left.' = বাম দিকে যান (both correct)।"),
        q("'Take the first turning on the right.' — এর অর্থ কী?", ["প্রথম মোড়ে ডানে ঘুরুন", "প্রথম মোড়ে বামে ঘুরুন", "সোজা যান", "পেছনে যান"], 0, "'Take the first turning on the right.' = first street to the right।"),
        q("কোনো জায়গার অবস্থান বলার উপায়?", ["It's on the corner.", "It's opposite the bank.", "It's next to the post office.", "সবগুলোই"], 3, "'On the corner / opposite / next to' = location prepositions।"),
        q("কোনো জায়গা 'বিপরীতে' আছে বোঝাতে কোন phrase ব্যবহার হয়?", ["It's opposite the school.", "It's near the school.", "It's next to the school.", "It's in front of school."], 0, "'Opposite' = বিপরীত পাশে।"),
        q("কোনো জায়গা 'পাশে' আছে বোঝাতে কোন phrase ব্যবহার হয়?", ["Next to", "Beside", "Near", "সবগুলোই"], 3, "'Next to / Beside / Near' — সবগুলোই পাশে বোঝায়।"),
        q("'It's at the end of the road.' — এর অর্থ কী?", ["রাস্তার শুরুতে", "রাস্তার শেষে", "রাস্তার মাঝে", "রাস্তার পাশে"], 1, "'At the end of the road' = রাস্তার শেষ মাথায়।"),
        q("'You can't miss it!' — direction দেওয়ার সময় এর অর্থ কী?", ["হারিয়ে যাবেন!", "খুঁজে পাবেনই (এটা খুব সহজ)", "মিস করবেন না", "এটা বড়"], 1, "'You can't miss it!' = It's easy to find / you will definitely find it।"),
        q("দূরত্ব বোঝাতে কোন phrase ব্যবহার করা হয়?", ["It's about 5 minutes from here.", "It's far from here.", "It's not far.", "সবগুলোই"], 3, "'It's about 5 minutes away / It's not far / It's far' — সবগুলো distance বোঝায়।"),
        q("কাউকে direction জিজ্ঞেস করার সঠিক উপায়?", ["Excuse me, how do I get to the station?", "Where is station?", "Station where?", "Tell station direction."], 0, "'Excuse me, how do I get to...' = polite way to ask for directions।"),
        q("Error: 'Go straight on the road.' — সঠিক?", ["সঠিক", "'Go straight down the road' হবে", "'Go straight along the road' হবে", "'On' ঠিক না"], 3, "'Go straight down/along the road' — 'on' possible but 'down/along' more common।"),
        q("Error: 'Turn to left.' — সঠিক?", ["'Turn left' (no 'to')", "'Turn to the left' — 'the' দিয়ে সম্ভব", "'Turn left' সবচেয়ে common", "সবগুলো"], 2, "'Turn left' (most common) / 'Turn to the left' (also possible)। 'Turn to left' (no article) — awkward।"),
        q("Error: 'It is located in the corner of Main Street.' — 'In' vs 'On'?", ["On the corner (correct)", "In the corner (indoor)", "দুটোই সঠিক", "ভুল"], 1, "'On the corner' = street corner (outdoor)। 'In the corner' = ঘরের ভিতরের কোণ।"),
        q("Error: 'Go straight for two blocks. It's on your right hand.' — ভুল?", ["Go straight", "two blocks", "on your right hand", "—"], 2, "'On your right' (not 'right hand')। 'It's on your right.'"),
        q("Fill: 'Go straight and take the first ___ (মোড়) on the left.'", ["turning", "turn", "corner", "road"], 0, "'Take the first turning / Take the first left' — 'turning' = মোড়।"),
        q("Fill: 'It's ___ (বিপরীতে) the hospital.'", ["opposite", "beside", "next to", "near"], 0, "'Opposite' = বিপরীতে।"),
        q("Fill: 'The bank is ___ (পাশে) the pharmacy.'", ["next to", "beside", "near", "সবগুলোই"], 3, "'Next to / Beside / Near' — সবগুলোই 'পাশে' বোঝায়।"),
        q("Fill: '___ me, is there a post office near here?'", ["Excuse", "Sorry", "Hello", "Hey"], 0, "'Excuse me' = polite attention-getter for asking directions।"),
        q("অনুবাদ: 'সোজা যান, তারপর প্রথম মোড়ে বামে ঘুরুন।'", ["Go straight, then turn first left.", "Go straight, then take the first left.", "Go straight, then first left turn.", "Go straight then left first."], 1, "'Go straight, then take the first left.' = common direction।"),
        q("অনুবাদ: 'এটি হাসপাতালের বিপরীতে অবস্থিত।'", ["It is opposite the hospital.", "It is beside the hospital.", "It is near the hospital.", "It is next to the hospital."], 0, "'Opposite' = বিপরীতে।")
    ]
}

# 70: Final Grand Review
ALL["mock_test_70"] = {
    "id": "mock_test_70", "testNumber": 70,
    "title": "Mock Test 70 - Final Grand Review",
    "description": "Level 1-4 (সমস্ত ৬৯টি টেস্ট) মিশ্র ২০টি চ্যালেঞ্জিং প্রশ্ন। Beginner Foundation, Intermediate Grammar, Advanced Grammar, Real-Life English — সব লেভেল থেকে। সবচেয়ে চ্যালেঞ্জিং টেস্ট।",
    "questions": [
        q("Which is correct?", ["He don't like tea.", "He doesn't likes tea.", "He doesn't like tea.", "He not like tea."], 2, "He (3rd person) → 'doesn't + V1'। 'He doesn't like tea.'"),
        q("Present Perfect: 'I ___ (live) here since 2019.'", ["live", "am living", "have lived", "lived"], 2, "Since 2019 → Present Perfect: 'have lived' (started in past, continues now)।"),
        q("Passive: 'The letter ___ (write) by her yesterday.'", ["wrote", "was written", "is written", "has been written"], 1, "Yesterday (Past) + Passive → 'was written'।"),
        q("Type 3 Conditional: 'If he ___ (study), he would have passed.'", ["studies", "studied", "had studied", "would study"], 2, "Type 3: If + had + V3 (had studied) → would have + V3।"),
        q("Indirect Speech: 'She said, \"I am busy.\"' → She said that ___", ["she is busy", "she was busy", "I am busy", "I was busy"], 1, "'I' → 'she', 'am' (Present) → 'was' (Past)।"),
        q("Relative Clause: 'The man ___ car was stolen is my neighbor.'", ["who", "which", "whose", "whom"], 2, "Possession → 'whose'। 'The man whose car was stolen'।"),
        q("Gerund vs Infinitive: 'I enjoy ___ (swim).'", ["swim", "to swim", "swimming", "swam"], 2, "'Enjoy + Ving' → 'enjoy swimming'।"),
        q("Phrasal Verb: 'She ___ up smoking last year.'", ["gave", "took", "put", "made"], 0, "'Give up' = quit। 'She gave up smoking.'"),
        q("Idiom: 'The exam was a piece of cake.' — অর্থ কী?", ["খুব কঠিন", "খুব সহজ", "খুব মজার", "খুব লম্বা"], 1, "'Piece of cake' = very easy।"),
        q("Collocation: 'Please ___ attention to the lesson.'", ["make", "do", "pay", "take"], 2, "'Pay attention' = মনোযোগ দেওয়া।"),
        q("Formal/Informal: Which is formal?", ["I need your help.", "I would like to request your assistance.", "Help me!", "I want help."], 1, "'I would like to request your assistance' = formal।"),
        q("Common Mistake: 'The dog wagged ___ (its/it's) tail.'", ["its", "it's", "its'", "it is"], 0, "'Its' = possessive (tail belongs to the dog)।"),
        q("Advanced Modal: 'You ___ have told me earlier.' (past regret)", ["should", "should have", "must have", "could have"], 1, "'Should have + V3' = past regret/criticism (উচিত ছিল কিন্তু করেনি)।"),
        q("Causative: 'I ___ my hair cut yesterday.'", ["had", "made", "let", "got"], 0, "'Had my hair cut' — have something done (causative)।"),
        q("Inversion: 'Never ___ such a beautiful sunset.'", ["I have seen", "have I seen", "I saw", "saw I"], 1, "'Never' → inversion: 'have I seen'।"),
        q("Subjunctive: 'I suggest that he ___ a doctor.'", ["sees", "see", "saw", "seeing"], 1, "'Suggest that + V1 (base)' → 'that he see'।"),
        q("Restaurant: 'Could I have the ___ (বিল), please?'", ["bill", "menu", "food", "water"], 0, "'The bill' = বিল।"),
        q("Job Interview: 'What are your ___ (শক্তি)?'", ["strengths", "weaknesses", "habits", "hobbies"], 0, "'Strengths' = শক্তি / গুণাবলী।"),
        q("Opinion: 'In my ___, this is a good idea.'", ["opinion", "mind", "thought", "view"], 0, "'In my opinion' = আমার মতে।"),
        q("Direction: 'Take the first ___ on the left.'", ["turning", "turn", "corner", "road"], 0, "'Take the first turning / take the first left' = সঠিক।")
    ]
}

# Write all
for fname, data in ALL.items():
    filepath = os.path.join(DIR, f"{fname}.json")
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"✓ {fname}.json written ({len(data['questions'])} questions)")

print(f"\n✅ All {len(ALL)} files generated successfully!")