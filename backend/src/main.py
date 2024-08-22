from logging.config import dictConfig
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import os 
import logging

from typing import Annotated

import tiktoken

from .log_config import log_config
from .azure_plugin import AzurePlugin

from semantic_kernel.agents.chat_completion_agent import ChatCompletionAgent
from semantic_kernel.connectors.ai.function_choice_behavior import FunctionChoiceBehavior
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion
from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.contents.utils.author_role import AuthorRole
# from semantic_kernel.filters.filter_types import FilterTypes
# from semantic_kernel.filters.prompts.prompt_render_context import PromptRenderContext
# from semantic_kernel.functions.kernel_function_decorator import kernel_function

from semantic_kernel.kernel import Kernel


# TODO - move this to a database
simple_in_memory_chat_history = {}


dictConfig(log_config)
logger = logging.getLogger("api-logger")

def num_tokens_from_string(string: str, encoding_name: str ='cl100k_base') -> int:
    """Returns the number of tokens in a text string."""
    encoding = tiktoken.get_encoding(encoding_name)
    num_tokens = len(encoding.encode(string))
    return num_tokens

token_limit = int(os.environ.get("TOKEN_LIMIT", 2048))

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
        async for content in agent.invoke(chat):
            print(f"# {content.role} - {content.name or '*'}: '{content.content}'")
        chat.add_message(content)

    return content


kernel = Kernel()

service_id = "agent"
kernel.add_service(AzureChatCompletion(service_id=service_id))

settings = kernel.get_prompt_execution_settings_from_service_id(service_id=service_id)
# Configure the function choice behavior to auto invoke kernel functions
settings.function_choice_behavior = FunctionChoiceBehavior.Auto()

kernel.add_plugin(plugin=AzurePlugin(), plugin_name="azure")

agent = ChatCompletionAgent(
    service_id="agent", kernel=kernel, name="Azure-Assistant", instructions="You are an assistant AI that helps find information about Azure resources", execution_settings=settings
)


app = FastAPI()

origins = [
    "*"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post("/echo")
def echo(data: dict):
    return {"echo": data}

@app.get("/me")
def me(request: Request):
    return {"headers": request.headers}


async def get_principal(request: Request):
    return request.headers.get("x-ms-client-principal-name", "default")

async def init_chat(request: Request):
    principal = await get_principal(request)
    if simple_in_memory_chat_history.get(principal, None) == None:
        logger.info(f"Initializing chat history for: {principal}")
        simple_in_memory_chat_history[principal] = ChatHistory()
        simple_in_memory_chat_history[principal].add_system_message("You are an Azure assistant named Labby. Your goal is to assist in saving money and setting up lab environments.")
        simple_in_memory_chat_history[principal].add_system_message("Welcome, I am Labby! How can I help you today?")

async def get_chat(request: Request):
    await init_chat(request)
    principal = await get_principal(request)
    logger.info(f"Getting chat history for: {principal}")        
    return simple_in_memory_chat_history[principal]

@app.post("/resetchat")
async def resetchat(request: Request):
    principal = await get_principal(request)
    logger.info(f"Resetting chat for: {principal}")
    simple_in_memory_chat_history.pop(principal, None) 
    await init_chat(request)
    return {"result": "Chat history has been reset."}

@app.post("/chat")
async def chat(request: Request, data: dict):  
    history = await get_chat(request)

    logger.info(f"Chat request: {data}")
    question = data.get("question")

    # Get the response from the AI
    result = await invoke_agent(agent, question, history)
    logger.info(f"Chat response: {result}")
    return {"result": f"{result}"}
