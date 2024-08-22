import { AuthenticatedTemplate, useMsal, UnauthenticatedTemplate } from '@azure/msal-react';
import { loginRequest, silentRequest } from './authConfig';
import Chat from './Chat'
import './MainContent.css'

export default function MainContent() {
    const { instance } = useMsal();
    const activeAccount = instance.getActiveAccount();

    const handleLoginRedirect = () => {
        instance.loginRedirect(loginRequest).catch((error) => console.log(error));
    };

    return (
        <div className="App">
            <AuthenticatedTemplate>
                {activeAccount ? (<>
                    <Chat />
                </>) : null}


            </AuthenticatedTemplate>
            <UnauthenticatedTemplate>
                <button className="signInButton" onClick={handleLoginRedirect} variant="primary">
                    Sign up
                </button>
            </UnauthenticatedTemplate>
        </div>
    )
}