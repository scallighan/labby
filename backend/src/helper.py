import os
import tiktoken

from fastapi import Request

from semantic_kernel.agents.chat_completion_agent import ChatCompletionAgent
from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.contents.utils.author_role import AuthorRole

token_limit = int(os.environ.get("TOKEN_LIMIT", 2048))

# From a string, return the estimated amount of tokens
def num_tokens_from_string(string: str, encoding_name: str ='cl100k_base') -> int:
    """Returns the number of tokens in a text string."""
    encoding = tiktoken.get_encoding(encoding_name)
    num_tokens = len(encoding.encode(string))
    return num_tokens

# A helper method to invoke the agent with the user input
async def invoke_agent(agent: ChatCompletionAgent, input: str, chat: ChatHistory, streaming=False) -> any:
    """Invoke the agent with the user input."""
    chat.add_user_message(input)

    full_prompt = chat.to_prompt()
    print(f"System> current full prompt: {full_prompt}")
    tokens = num_tokens_from_string(full_prompt)
    print(f"System> current full prompt tokens: {tokens}")
    while(tokens > token_limit and len(chat.messages) > 1):
        print(f"removing a message...")
        # remove the "oldest" message but keep the system message
        chat.remove_message(chat.messages[1])
        full_prompt = chat.to_prompt()
        print(f"System> current full prompt: {full_prompt}")
        tokens = num_tokens_from_string(full_prompt)
        print(f"System> current full prompt tokens: {tokens}")

    if (tokens > token_limit) and len(chat.messages) == 1:
        raise Exception("The prompt is too long and cannot be processed")

    print(f"# {AuthorRole.USER}: '{input}'")

    if streaming:
        contents = []
        content_name = ""
        async for content in agent.invoke_stream(chat):
            content_name = content.name
            contents.append(content)
        message_content = "".join([content.content for content in contents])
        print(f"# {content.role} - {content_name or '*'}: '{message_content}'")
        chat.add_assistant_message(message_content)
    else:
        try:
            async for content in agent.invoke(chat):
                print(f"# {content.role} - {content.name or '*'}: '{content.content}'")
            #chat.add_message(content)
            chat.add_assistant_message(content.content)
        except Exception as e:
            print(f"Error: {e}")
            # a common error is that when clenaing up the tokens we removed the tool_calls message and so we get in an error loop. This removes the bad message and then lets us prompt the user to try again.
            chat.remove_message(chat.messages[1])
            content = "I'm sorry, I had trouble processing your request. Please try again."
            

    return content

async def get_principal(request: Request):
    return request.headers.get("x-ms-client-principal-name", "default")