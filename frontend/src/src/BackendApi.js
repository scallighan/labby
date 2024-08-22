import { useMsal } from '@azure/msal-react';
import { silentRequest } from './authConfig';


class BackendApi {
    
    baseurl;
    msalinstance;
    activeaccount;

    constructor() {
        this.baseurl = import.meta.env.VITE_BASE_URL
        const { instance } = useMsal()        
        this.msalinstance = instance
        this.activeaccount = this.msalinstance.getActiveAccount();
    }

    async generateBearerToken() {
        const response = await this.msalinstance.acquireTokenSilent({
            ...silentRequest,
            account: this.activeaccount
        });
        console.log(response)
        //let token = response.idToken;   
        let token = response.accessToken;
        return token;
    }

    async echo(question) {
        const accessToken = await this.generateBearerToken();
        const resp = await fetch(`${this.baseurl}/echo`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({question: question})
        });
        return await resp.json();
    }

    async chat(question) {
        const accessToken = await this.generateBearerToken();
        const resp = await fetch(`${this.baseurl}/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({question: question})
        });
        return await resp.json();
    }

    async resetchat(){
        const accessToken = await this.generateBearerToken();
        const resp = await fetch(`${this.baseurl}/resetchat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            }
        });
        return await resp.json();
    }
}

export { BackendApi }