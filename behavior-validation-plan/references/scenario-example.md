# Scenario Example: Design → Behavior Test Scenarios

Use this as a quality anchor during Phase 3 (Formulation). The scenarios here represent the target granularity and abstraction level.

---

## Input: design.md Excerpt

```markdown
## Feature: Streaming Chat Pipeline

### Overview

Users send messages to an AI agent via a chat interface. The backend streams responses token-by-token via SSE. Conversations persist within a session so the agent can reference earlier messages.

### Decisions

- Streaming uses SSE with AI SDK UIMessage Stream Protocol v1
- Conversation state persists across requests within the same session (via LangGraph checkpointer with thread_id = session_id)
- Regenerate replaces only the last assistant turn and re-streams
- If the SSE connection drops mid-stream, the server stops LLM execution

### Tech Stack

- Backend: POST /api/v1/chat/stream (SSE), POST /api/v1/chat (sync fallback)
- Frontend: /chat page, useChat() hook with DefaultChatTransport

---

## Feature: Chat UI Experience

### Overview

The chat interface renders agent responses in real-time. Tool usage is shown inline as collapsible cards with state transitions.

### Decisions

- Text renders incrementally as SSE text-delta events arrive
- Tool cards show 3 visual states: executing (amber), success (green),
  error (red). A transient progress message overlays during execution.
- Stream-level errors display as an inline error block with a Retry button
  that triggers regenerate
- Clear Session creates a new session ID, resetting the conversation
- Stop button sends abort signal, halting the active stream

### Tech Stack

- Frontend: React + useChat() + shadcn/ui components
- Tool progress: transient data-tool-progress SSE events, managed
  via useToolProgress hook (not persisted in message parts)
```

---

## Step 1: Extract Rules

| Design Decision                                                          | Extracted Rule                       |
| ------------------------------------------------------------------------ | ------------------------------------ |
| "Conversation state persists across requests within the same session"    | Conversation persists within session |
| "Regenerate replaces only the last assistant turn and re-streams"        | Regenerate replaces last response    |
| "If the SSE connection drops mid-stream, the server stops LLM execution" | Server stops on client disconnect    |
| "Text renders incrementally as SSE text-delta events arrive"             | Streaming text renders incrementally |
| "Tool cards show 3 visual states"                                        | Tool cards reflect execution state   |
| "Stream-level errors display as inline error block with Retry"           | Stream error shows Retry option      |
| "Clear Session creates a new session ID"                                 | Clear Session resets conversation    |
| "Stop button sends abort signal"                                         | Stop button halts active stream      |

---

## Step 2: Write Scenarios

### Feature: Streaming Chat Pipeline

#### Context

Backend streams AI agent responses via SSE. Conversations persist within sessions using a checkpointer.

#### Rule: Conversation persists within session

##### S-chat-01: Second message in same session references first conversation

> Verifies that the agent receives conversation history from the checkpointer

- **Given** Alice sent "My name is Alice" in session abc-123 and received a response
- **When** she sends "What's my name?" in the same session
- **Then** the response references "Alice" — proving conversation state was preserved

Category: Illustrative
Origin: Dev

##### S-chat-02: Different session IDs produce independent conversations

> Verifies session isolation — no state leaks between sessions

- **Given** Bob sent "My name is Bob" in session sess-111
- **When** he sends "What's my name?" in a different session sess-222
- **Then** the response does not reference "Bob" — proving sessions are isolated

Category: Illustrative
Origin: QA

#### Rule: Regenerate replaces last response

##### S-chat-03: Regenerate produces a new response for the same question

> Verifies that regenerate removes the previous assistant turn and re-streams

- **Given** Carol asked a question and received a response in session sess-333
- **When** she triggers regenerate for that response
- **Then** the previous response is replaced and a new streamed response begins

Category: Illustrative
Origin: PO

#### Rule: Server stops on client disconnect

##### S-chat-04: Server stops streaming when client disconnects

> Verifies resource cleanup on connection drop

- **Given** Dave starts a streaming request
- **When** the client connection is aborted mid-stream
- **Then** the server stops LLM execution within a reasonable time — no orphaned processing

Category: Illustrative
Origin: Dev

---

#### Journey Scenarios

##### J-chat-01: Complete conversation flow with multi-turn context

> Proves the full pipeline works: send → stream → persist → reference in next turn

- **Given** a user opens the chat for the first time
- **When** she sends a message, receives a streamed response, then sends a follow-up referencing the first exchange
- **Then** the follow-up response demonstrates awareness of the earlier conversation

Category: Journey
Origin: Multiple

---

### Feature: Chat UI Experience

#### Context

The frontend renders streaming responses in real-time with tool cards, error handling, and session management.

#### Rule: Streaming text renders incrementally

##### S-chat-05: User sees text appear progressively during streaming

> Verifies that tokens render as they arrive, not all at once after completion

- **Given** Eve opens the chat page
- **When** she sends a message
- **Then** text begins appearing within a few seconds and continues to grow until the response completes

Category: Illustrative
Origin: PO

#### Rule: Tool cards reflect execution state

##### S-chat-06: Tool card transitions from executing to completed

> Verifies the tool card visual state lifecycle

- **Given** Frank sends a question that triggers a tool call
- **When** the agent executes the tool
- **Then** the tool card first shows an amber "executing" state, then transitions to green "completed" when the tool returns

Category: Illustrative
Origin: Dev

##### S-chat-07: Tool card shows progress message during execution

> Verifies that transient progress events appear on the tool card

- **Given** Grace sends a question that triggers a tool with progress reporting
- **When** the tool emits progress messages during execution
- **Then** the tool card displays the progress text (e.g., "Fetching stock data...") which disappears after completion

Category: Illustrative
Origin: QA

#### Rule: Stream error shows Retry option

##### S-chat-08: Stream error displays error block with working Retry

> Verifies error recovery flow from the user's perspective

- **Given** Hank is in an active chat session
- **When** a streaming request fails
- **Then** an inline error block appears with a Retry button
- **And** clicking Retry triggers regenerate and a new response streams successfully

Category: Illustrative
Origin: QA

#### Rule: Clear Session resets conversation

##### S-chat-09: Clear Session starts a fresh conversation

> Verifies that clearing resets all visible state

- **Given** Ivan has an ongoing conversation with several messages
- **When** he clicks Clear Session
- **Then** the message list is empty and a new message does not reference previous conversation content

Category: Illustrative
Origin: PO

#### Rule: Stop button halts active stream

##### S-chat-10: Stop button interrupts streaming and preserves partial response

> Verifies the abort flow from the user's perspective

- **Given** Julia is receiving a streaming response
- **When** she clicks the Stop button
- **Then** streaming stops, the partial response remains visible, and the input is re-enabled

Category: Illustrative
Origin: Dev

---

#### Journey Scenarios

##### J-chat-02: Error recovery through Retry

> Proves the error → retry → success flow works end-to-end

- **Given** a user is in an active chat session
- **When** she sends a message, the stream fails, she clicks Retry
- **Then** the error block is replaced by a new streamed response that completes successfully

Category: Journey
Origin: Multiple

##### J-chat-03: Full UI lifecycle — send, stream, tool card, complete

> Proves the streaming UI works from first interaction to completed response with tool usage

- **Given** a new user opens the chat page
- **When** she sends a question that triggers tool execution
- **Then** she sees streaming text appear, a tool card with state transitions, and a complete response with the tool card in its final state

Category: Journey
Origin: Multiple

---

## Why These Scenarios Are Well-Calibrated

**BRIEF check on S-chat-01:**

- **B**usiness language: "sent", "received a response", "references Alice" — not "POST returns 200" or "checkpointer stores messages"
- **R**eal data: "My name is Alice", session "abc-123" — concrete values, not "some message"
- **I**ntention revealing: title says "Second message in same session references first conversation" — immediately clear what's tested
- **E**ssential: no mention of SSE protocol, LangGraph, checkpointer implementation — irrelevant to this Rule
- **F**ocused: tests only session persistence, nothing else

**Backend vs frontend Rules determine verification method.** S-chat-01 (conversation persistence) is a backend behavior — verified via API calls. S-chat-05 (streaming text renders incrementally) is a frontend behavior — verified via Browser-Use CLI. The scenario text doesn't dictate the verification method; the layer where the Rule operates does.

**Behavior test vs unit test.** Every scenario here has a behavior trigger (user sends message, clicks button), state flow (conversation history, tool card transitions), and an observable outcome (sees text, sees tool card change color). None of them test a single API endpoint's response format — that's unit test territory.

**Behavior test vs agent evaluation.** None of these scenarios check response quality, tool selection correctness, or LLM reasoning. S-chat-01 verifies that the pipeline delivers conversation history to the agent — what the agent does with that history is evaluation's concern.
