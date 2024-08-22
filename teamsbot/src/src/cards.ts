import { Attachment, CardFactory } from 'botbuilder';

/**
 * @returns {any} initial adaptive card.
 */
export function createProfileCard(displayName: string, mail: string, preferredLanguage: string): Attachment {
    return CardFactory.adaptiveCard({
        "type": "AdaptiveCard",
        "body": [
            {
                "type": "TextBlock",
                "size": "Medium",
                "weight": "Bolder",
                "text": "Welcome!"
            },
            {
                "type": "FactSet",
                "facts": [
                    {
                        "title": "Name",
                        "value": `${displayName}`
                    },
                    {
                        "title": "Email",
                        "value": `${mail}`
                    }
                    ,
                    {
                        "title": "Preferred Language",
                        "value": `${preferredLanguage}`
                    }
                ]
            }
        ],
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.6"
    });
}


export function createSearchResultsCard(searchResults: any): Attachment {
    let searchTerms = ""
    const searchItems = []
    for(let v of searchResults.value) {
        //console.log(v)
        searchTerms = v.searchTerms
        for(let hitsContainers of v.hitsContainers){
            console.log(hitsContainers)
            if(hitsContainers.total > 0){
                for(let hit of hitsContainers.hits){
                    //console.log(hit)
                    const item = {
                        "type": "Container",
                        "seperator": true,
                        "style": "emphasis",
                        "items": [
                            {
                                "type": "TextBlock",
                                "size": "Medium",
                                "weight": "Bolder",
                                "text": `${hit.resource.name}`
                            },
                            {
                                "type": "RichTextBlock",
                                "inlines": [
                                    {
                                        "type": "TextRun",
                                        "text": `${hit.summary}`
                                    }
                                ]
                            },
                            {
                                "type": "FactSet",
                                "facts": [
                                    {
                                        "title": "lastModifiedDateTime",
                                        "value": `${hit.resource.lastModifiedDateTime}`
                                    },
                                    {
                                        "title": "lastModifiedBy",
                                        "value": `${hit.resource.lastModifiedBy.user.displayName}`
                                    }
                                ]
                            },
                            {
                                "type": "ActionSet",
                                "actions": [
                                    {
                                        "type": "Action.OpenUrl",
                                        "title": `${hit.resource.name}`,
                                        "url": `${hit.resource.webUrl}`
                                    }
                                ]
                            }
                        ]
                    }
                    searchItems.push(item)
                    
                }
            }
        }
    }
    console.log(searchItems)
    return CardFactory.adaptiveCard({
        "type": "AdaptiveCard",
        "body": [
            {
                "type": "TextBlock",
                "size": "Medium",
                "weight": "Bolder",
                "text": `Search results for: ${searchTerms}`
            },
            {
                "type": "Container",
                "items": searchItems
            }
            
        ],
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.6"
    });
}