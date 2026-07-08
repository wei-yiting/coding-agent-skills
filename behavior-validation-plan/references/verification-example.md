# Verification Example: Scenarios → Verification Plan

Use this as a quality anchor during Phase 4 (Verification Planning). These entries correspond to the scenarios in `references/scenario-example.md`.

---

## Automated Verification — Deterministic

Backend behaviors verified via curl/script. Each entry chains state between steps — output from one step feeds the next.

#### S-chat-01: Second message in same session references first conversation
- **Method**: script
- **Steps**:
  1. Generate a session ID: `SESSION_ID=$(uuidgen)`
  2. Send first message: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"$SESSION_ID\",\"message\":\"My name is Alice\"}" > /tmp/response1.txt`
  3. Wait for stream to complete (look for `[DONE]` event)
  4. Send second message with same session ID: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"$SESSION_ID\",\"message\":\"What is my name?\"}" > /tmp/response2.txt`
  5. Parse text-delta events from response2.txt, concatenate into full response text
  6. Assert: response text contains "Alice"
- **Expected**: Second response references "Alice" — session state was preserved by checkpointer

#### S-chat-02: Different session IDs produce independent conversations
- **Method**: script
- **Steps**:
  1. Send "My name is Bob" with session ID `sess-111`, wait for completion
  2. Send "What is my name?" with a different session ID `sess-222`: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"sess-222\",\"message\":\"What is my name?\"}" > /tmp/response_isolated.txt`
  3. Parse text-delta events, concatenate into full response text
  4. Assert: response does NOT contain "Bob"
- **Expected**: Second session has no knowledge of first — sessions are isolated

#### S-chat-03: Regenerate produces a new response for the same question
- **Method**: script
- **Steps**:
  1. Send a message in session `sess-333`, capture complete response and message ID from the `start` event: `MESSAGE_ID=$(grep '"type":"start"' /tmp/first_response.txt | jq -r '.messageId')`
  2. Send regenerate request: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"sess-333\",\"trigger\":\"regenerate\",\"messageId\":\"$MESSAGE_ID\"}" > /tmp/regen_response.txt`
  3. Parse text-delta events from regenerated response
  4. Assert: regenerated response has a new `start` event with a different messageId
  5. Send a follow-up message in same session, assert it only sees one assistant response for the original question (the regenerated one, not both)
- **Expected**: Previous response replaced, new response streamed — conversation history contains only the regenerated version

#### S-chat-04: Server stops streaming when client disconnects
- **Method**: script
- **Steps**:
  1. Start a streaming request in background: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d '{"id":"sess-dc","message":"Write a very long essay about the history of computing"}' > /tmp/dc_response.txt & CURL_PID=$!`
  2. Wait 2 seconds for streaming to begin: `sleep 2`
  3. Kill the client connection: `kill $CURL_PID`
  4. `[POST-CODING: check server logs or Langfuse traces to confirm LLM execution stopped shortly after disconnect]`
- **Expected**: Server detects disconnect and stops processing — no orphaned LLM calls consuming resources

---

## Automated Verification — Browser Automation

Frontend behaviors verified via Playwright scripts (webapp-testing skill). These behaviors only exist in the UI layer. Each snippet runs inside the standard boilerplate — `sync_playwright()`, headless chromium, `page.wait_for_load_state('networkidle')` after `page.goto`, with `expect` imported from `playwright.sync_api`.

#### S-chat-05: User sees text appear progressively during streaming
- **Method**: Browser automation (Playwright script)
- **Steps**:
  ```python
  page.goto("http://localhost:5173/chat")
  page.wait_for_load_state("networkidle")
  page.get_by_role("textbox").fill("Tell me about stock market trends")
  page.get_by_role("button", name="Send").click()
  page.wait_for_selector("text=stock")                     # first content appears
  page.screenshot(path="/tmp/s-chat-05-partial.png")       # capture partial response
  page.wait_for_selector("[data-status='ready']")          # stream completes
  page.screenshot(path="/tmp/s-chat-05-complete.png")      # capture complete response
  # Assert: complete screenshot shows more text than partial screenshot
  ```
- **Expected**: Text appears progressively — partial screenshot shows beginning of response, complete screenshot shows the full response

#### S-chat-06: Tool card transitions from executing to completed
- **Method**: Browser automation (Playwright script)
- **Steps**:
  ```python
  page.goto("http://localhost:5173/chat")
  page.wait_for_load_state("networkidle")
  # Message that triggers a tool call
  page.get_by_role("textbox").fill("What is the current price of AAPL?")
  page.get_by_role("button", name="Send").click()
  page.wait_for_selector("[data-tool-state='input-available']")   # tool card appears in executing state
  page.screenshot(path="/tmp/s-chat-06-executing.png")            # capture amber state
  page.wait_for_selector("[data-tool-state='output-available']")  # tool completes
  page.screenshot(path="/tmp/s-chat-06-completed.png")            # capture green state
  # Assert: executing screenshot shows amber indicator, completed screenshot shows green indicator
  ```
- **Expected**: Tool card visually transitions from amber (executing) to green (completed)

#### S-chat-08: Stream error displays error block with working Retry
- **Method**: Browser automation (Playwright script)
- **Steps**:
  ```python
  page.goto("http://localhost:5173/chat")
  page.wait_for_load_state("networkidle")
  # [POST-CODING: trigger an error condition — e.g., temporarily stop the backend, send a message, then restart]
  page.wait_for_selector("[data-testid='stream-error-block']")    # error block appears
  page.screenshot(path="/tmp/s-chat-08-error.png")
  page.get_by_role("button", name="Retry").click()
  page.wait_for_selector("[data-status='streaming']")             # new response starts streaming
  page.wait_for_selector("[data-status='ready']")                 # stream completes
  page.screenshot(path="/tmp/s-chat-08-recovered.png")
  expect(page.locator("[data-testid='stream-error-block']")).not_to_be_visible()
  # Assert: error screenshot shows error block + Retry button; recovered screenshot shows a complete response with no error block
  ```
- **Expected**: Error shows with Retry → clicking Retry produces a successful new response

#### S-chat-09: Clear Session starts a fresh conversation
- **Method**: Browser automation (Playwright script)
- **Steps**:
  ```python
  page.goto("http://localhost:5173/chat")
  page.wait_for_load_state("networkidle")
  page.get_by_role("textbox").fill("Remember this: the code is 42")
  page.get_by_role("button", name="Send").click()
  page.wait_for_selector("[data-status='ready']")                 # wait for response
  page.get_by_role("button", name="Clear Session").click()
  page.screenshot(path="/tmp/s-chat-09-cleared.png")              # message list should be empty
  page.get_by_role("textbox").fill("What was the code?")
  page.get_by_role("button", name="Send").click()
  page.wait_for_selector("[data-status='ready']")                 # wait for response
  # Extract response text (adjust locator to the app's assistant-message element)
  response_text = page.locator("{response-element-selector}").last.inner_text()
  assert "42" not in response_text
  # Assert: cleared screenshot shows empty message list; response text does NOT contain "42"
  ```
- **Expected**: Clear Session wipes visible history AND creates a new session — agent has no memory of previous conversation

#### S-chat-10: Stop button interrupts streaming and preserves partial response
- **Method**: Browser automation (Playwright script)
- **Steps**:
  ```python
  page.goto("http://localhost:5173/chat")
  page.wait_for_load_state("networkidle")
  # Message that produces a long response
  page.get_by_role("textbox").fill("Write a detailed analysis of recent market trends")
  page.get_by_role("button", name="Send").click()
  page.wait_for_selector("[data-status='streaming']")             # streaming begins
  page.wait_for_timeout(2000)                                     # deliberate mid-stream pause for partial content
  page.get_by_role("button", name="Stop").click()
  page.screenshot(path="/tmp/s-chat-10-stopped.png")
  # Input re-enabled: Send button visible again, Stop button gone
  expect(page.get_by_role("button", name="Send")).to_be_visible()
  expect(page.get_by_role("button", name="Stop")).not_to_be_visible()
  # Assert: screenshot shows partial response text; input area is re-enabled for new messages
  ```
- **Expected**: Streaming stops, partial text remains visible, input re-enables — user is not stuck

---

## Automated Verification — Journey Scenarios (Deterministic)

Journey scenarios chain the full flow via API. Each step's output feeds the next.

#### J-chat-01: Complete conversation flow with multi-turn context
- **Method**: script
- **Steps**:
  1. Generate session: `SESSION_ID=$(uuidgen)`
  2. Send first message: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"$SESSION_ID\",\"message\":\"I am planning to invest in tech stocks. My budget is 10000 dollars.\"}" > /tmp/j01-turn1.txt`
  3. Wait for `[DONE]` event
  4. Send follow-up referencing context: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"$SESSION_ID\",\"message\":\"Given my budget, what allocation would you suggest?\"}" > /tmp/j01-turn2.txt`
  5. Wait for `[DONE]` event
  6. Parse text-delta events from turn 2, concatenate into full response
  7. Assert: response references either "10000", "10,000", or "budget" — proving multi-turn context was preserved
- **Expected**: Complete two-turn conversation flows through pipeline; second turn demonstrates context awareness

#### J-chat-02: Error recovery through Retry
- **Method**: script
- **Steps**:
  1. `[POST-CODING: determine how to trigger a controlled stream failure — e.g., invalid model config, temporary API key invalidation]`
  2. Send message that triggers failure, capture error event: `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d '{"id":"sess-err","message":"test"}' > /tmp/j02-error.txt`
  3. Assert: response contains an error event (not just a dropped connection)
  4. `[POST-CODING: restore normal operation]`
  5. Send regenerate: `MESSAGE_ID=$(grep '"type":"start"' /tmp/j02-error.txt | jq -r '.messageId')` then `curl -s -N -X POST http://localhost:8000/api/v1/chat/stream -H "Content-Type: application/json" -d "{\"id\":\"sess-err\",\"trigger\":\"regenerate\",\"messageId\":\"$MESSAGE_ID\"}" > /tmp/j02-retry.txt`
  6. Wait for `[DONE]` event
  7. Assert: retry response contains text-delta events and completes successfully
- **Expected**: Error → regenerate → successful response. The retry mechanism recovers from stream failures.

---

## Automated Verification — Journey Scenarios (Browser Automation)

Same journeys verified through the UI to prove frontend integration works. Same Playwright conventions as the section above.

#### J-chat-03: Full UI lifecycle — send, stream, tool card, complete
- **Method**: Browser automation (Playwright script)
- **Steps**:
  ```python
  page.goto("http://localhost:5173/chat")
  page.wait_for_load_state("networkidle")
  page.get_by_role("textbox").fill("What is the current price of AAPL?")
  page.get_by_role("button", name="Send").click()
  page.wait_for_selector("[data-status='streaming']")   # streaming starts
  page.screenshot(path="/tmp/j03-streaming.png")
  page.wait_for_selector("[data-tool-state]")           # tool card appears
  page.screenshot(path="/tmp/j03-tool-executing.png")
  page.wait_for_selector("[data-status='ready']")       # response complete
  page.screenshot(path="/tmp/j03-complete.png")
  # Assert: streaming screenshot shows partial text; tool screenshot shows tool card;
  # complete screenshot shows full response with tool card in final state
  ```
- **Expected**: Full lifecycle visible: streaming text → tool card appears → response completes with tool result integrated

---

## Manual Verification — User Acceptance Test

#### J-chat-03: Full UI lifecycle — send, stream, tool card, complete
- **Acceptance Question**: Does the streaming chat experience feel responsive and polished?
- **Steps**:
  1. Open the chat and send several different questions
  2. Observe: Does text appear smoothly? Any jarring jumps or flashes?
  3. When tool cards appear, is the state transition clear (amber → green)?
  4. Is the tool progress message visible and informative during execution?
  5. Try Clear Session — does the transition feel clean?
  6. Try Stop mid-stream — does partial text remain readable?
- **Expected**: Smooth, responsive experience with clear visual feedback at each stage

---

## Key Patterns to Notice

1. **Backend scenarios use API with state chaining.** S-chat-01 sends two requests to the same session ID — the second request's assertion proves the first request's state was preserved. S-chat-03 captures a message ID from the first response and feeds it into the regenerate request.

2. **Frontend scenarios use Playwright scripts (webapp-testing skill).** S-chat-05 through S-chat-10 test behaviors that only exist in the UI — streaming rendering, tool card transitions, error display, button interactions. Curl cannot observe these.

3. **Journey scenarios get both layers.** J-chat-01 has a deterministic API version (fast, proves pipeline works) and J-chat-03 has a browser version (slower, proves UI renders correctly). They test different failure modes of the same flow.

4. **"Prove it" assertions.** S-chat-01 doesn't just check "second request returns 200" — it checks that the response text contains "Alice", proving the conversation state actually reached the agent. S-chat-09 doesn't just check "message list is empty" — it also sends a follow-up and verifies the agent has no memory of "42".

5. **No quality or evaluation assertions.** No scenario checks whether the response is "good", "relevant", or "grounded". S-chat-01 checks that conversation state was delivered to the agent (structural behavior), not whether the agent's response was high-quality (evaluation concern).
