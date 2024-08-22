from logging.config import dictConfig
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

import logging

from .helper import invoke_agent, get_principal
from .log_config import log_config
from .azure_plugin import AzurePlugin

from semantic_kernel.agents.chat_completion_agent import ChatCompletionAgent
from semantic_kernel.connectors.ai.function_choice_behavior import FunctionChoiceBehavior
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion
from semantic_kernel.contents.chat_history import ChatHistory

from semantic_kernel.kernel import Kernel

dictConfig(log_config)
logger = logging.getLogger("api-logger")



# Configure semantic kernel
kernel = Kernel()
service_id = "agent"
kernel.add_service(AzureChatCompletion(service_id=service_id))

# Get the execution settings for the service
settings = kernel.get_prompt_execution_settings_from_service_id(service_id=service_id)
# Configure the function choice behavior to auto invoke kernel functions
settings.function_choice_behavior = FunctionChoiceBehavior.Auto()
# Add the Azure plugin
kernel.add_plugin(plugin=AzurePlugin(), plugin_name="azure")
# Create a ChatCompletionAgent
agent = ChatCompletionAgent(
    service_id="agent", kernel=kernel, name="Azure-Assistant", instructions="You are an assistant AI named Labby that helps find information about Azure resources. Your goal is to assist in saving money and setting up lab environments.", execution_settings=settings
)

# Chat history helpers
# TODO - move this to a database
simple_in_memory_chat_history = {}
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
