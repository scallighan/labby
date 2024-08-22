import './App.css'
import MainContent from './MainContent'
import { MsalProvider } from '@azure/msal-react';

function App({ instance }) {
  

  return (
    <>
      <MsalProvider instance={instance}>
        <MainContent />
      </MsalProvider>
    </>
  )
}

export default App
