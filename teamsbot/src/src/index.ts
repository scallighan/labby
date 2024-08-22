/* eslint-disable @typescript-eslint/no-unused-vars */
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Import required packages
import { config } from 'dotenv';
import * as path from 'path';
import * as restify from 'restify';

// Import required bot services.
// See https://aka.ms/bot-services to learn more about the different parts of a bot.
import { ActivityTypes, ConfigurationServiceClientCredentialFactory, MemoryStorage, TurnContext } from 'botbuilder';

import { ApplicationBuilder, AuthError, TurnState, TeamsAdapter } from '@microsoft/teams-ai';


import { createProfileCard, createSearchResultsCard } from './cards';

// Read botFilePath and botFileSecret from .env file.
const ENV_FILE = path.join(__dirname, '..', '.env');
config({ path: ENV_FILE });

const baseurl = process.env.BASE_URL;

// Create adapter.
// See https://aka.ms/about-bot-adapter to learn more about how bots work.
const adapter = new TeamsAdapter(
    {},
    new ConfigurationServiceClientCredentialFactory({
        MicrosoftAppId: process.env.BOT_ID,
        MicrosoftAppPassword: process.env.BOT_PASSWORD,
        MicrosoftAppType: 'SingleTenant',
        MicrosoftAppTenantId: process.env.AAD_APP_TENANT_ID
    })
);

// Catch-all for errors.
const onTurnErrorHandler = async (context: any, error: any) => {
    // This check writes out errors to console log .vs. app insights.
    // NOTE: In production environment, you should consider logging this to Azure
    //       application insights.
    console.error(`\n [onTurnError] unhandled error: ${error.toString()}`);

    // Send a trace activity, which will be displayed in Bot Framework Emulator
    await context.sendTraceActivity(
        'OnTurnError Trace',
        `${error.toString()}`,
        'https://www.botframework.com/schemas/error',
        'TurnError'
    );

    // Send a message to the user
    await context.sendActivity('The bot encountered an error or bug.');
    await context.sendActivity('To continue to run this bot, please fix the bot source code.');
};

// Set the onTurnError for the singleton CloudAdapter.
adapter.onTurnError = onTurnErrorHandler;

// Create HTTP server.
const server = restify.createServer();
server.use(restify.plugins.bodyParser());

server.listen(process.env.port || process.env.PORT || 3978, () => {
    console.log(`\n${server.name} listening to ${server.url}`);
    console.log('\nGet Bot Framework Emulator: https://aka.ms/botframework-emulator');
    console.log('\nTo test your bot in Teams, sideload the app manifest.json within Teams Apps.');
});

interface ConversationState {
    count: number;
}
type ApplicationTurnState = TurnState<ConversationState>;

// Define storage and application
const storage = new MemoryStorage();
const app = new ApplicationBuilder<ApplicationTurnState>()
    .withStorage(storage)
    .withAuthentication(adapter, {
        settings: {
            graph: {
                scopes: ['User.Read', `api://${process.env.BACKEND_CLIENT_ID}/Apis.Chat`],
                msalConfig: {
                    auth: {
                        clientId: process.env.AAD_APP_CLIENT_ID!,
                        clientSecret: process.env.AAD_APP_CLIENT_SECRET!,
                        authority: `${process.env.AAD_APP_OAUTH_AUTHORITY_HOST}/${process.env.AAD_APP_TENANT_ID}`
                    }
                },
                signInLink: `https://${process.env.BOT_DOMAIN}/auth-start.html`,
                endOnInvalidMessage: true
            }
        }
    })
    .build();


// Listen for user to say '/reset' and then delete conversation state
app.message('/reset', async (context: TurnContext, state: ApplicationTurnState) => {
    state.deleteConversationState();
    const headers = {
        Authorization: `Bearer ${state.temp.authTokens['graph']}`,
        'Content-Type': 'application/json'
    }
    const resp = await fetch(`${baseurl}/resetchat`, {
        method: 'POST',
        headers
    });
    await context.sendActivity(`Ok I've deleted the current conversation state. (${resp.status})`);
});

app.message('/signout', async (context: TurnContext, state: ApplicationTurnState) => {
    await app.authentication.signOutUser(context, state);

    // Echo back users request
    await context.sendActivity(`You have signed out`);
});

app.message('/me', async (context: TurnContext, state: ApplicationTurnState) => {
    console.log("Return who is logged in")
    //console.log(state.temp.authTokens['graph']);
    console.log(`Attempting to fetch ${baseurl}/me`);
    const resp = await fetch(`${baseurl}/me`, { 
        headers: { 
            Authorization: `Bearer ${state.temp.authTokens['graph']}`
        }
    });
    const respjson = await resp.json();
    console.log(`Response: (${resp.status}) ${respjson}`);
    await context.sendActivity(JSON.stringify(respjson));
});

app.message('/graphme', async (context: TurnContext, state: ApplicationTurnState) => {
    console.log("Return who is logged in")
    //console.log(state.temp.authTokens['graph']);

    const resp = await fetch('https://graph.microsoft.com/v1.0/me', { 
        headers: { 
            Authorization: `Bearer ${state.temp.authTokens['graph']}`
        }
    });
    const respjson = await resp.json();
    const profileCard = createProfileCard(respjson.displayName, respjson.mail, respjson.preferredLanguage);
    await context.sendActivity({ attachments: [profileCard] });
});

// Listen for ANY message to be received. MUST BE AFTER ANY OTHER MESSAGE HANDLERS
app.activity(ActivityTypes.Message, async (context: TurnContext, state: ApplicationTurnState) => {
    // Increment count state
    let count = state.conversation.count ?? 0;
    state.conversation.count = ++count;

    //console.log(state.temp.authTokens['graph']);
    const headers = {
        Authorization: `Bearer ${state.temp.authTokens['graph']}`,
        'Content-Type': 'application/json'
    }

    const body = {
        "question": `${context.activity.text}`
    }

    console.log(`Attempting to fetch ${baseurl}/chat`);
    
    const resp = await fetch(`${baseurl}/chat`, {
        method: 'POST',
        headers,
        body: JSON.stringify(body)
    });
    const respjson = await resp.json();
    console.log(`Response: (${resp.status}) ${respjson}`);
    await context.sendActivity(respjson.result);
});

app.authentication.get('graph').onUserSignInSuccess(async (context: TurnContext, state: ApplicationTurnState) => {
    // Successfully logged in
    await context.sendActivity('Successfully logged in');
    await context.sendActivity(`Token string length: ${state.temp.authTokens['graph']!.length}`);

    await context.sendActivity(`How can I be of assistance?`);
});

app.authentication
    .get('graph')
    .onUserSignInFailure(async (context: TurnContext, _state: ApplicationTurnState, error: AuthError) => {
        // Failed to login
        await context.sendActivity('Failed to login');
        await context.sendActivity(`Error message: ${error.message}`);
    });

// Listen for incoming server requests.
server.post('/api/messages', async (req, res) => {
    // Route received a request to adapter for processing
    await adapter.process(req, res as any, async (context) => {
        // Dispatch to application for routing
        await app.run(context);
    });
});

server.get(
    '/auth-:name(start|end).html',
    restify.plugins.serveStatic({
        directory: path.join(__dirname, 'public')
    })
);
