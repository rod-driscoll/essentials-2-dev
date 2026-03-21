import { MobileControlProvider } from '../lib/shared/MobileControlProvider/MobileControlProvider';
import RoomBusiness from '../components/roomBusiness/RoomBusiness';

function App() {
  return (
    <MobileControlProvider>
      <RoomBusiness />
    </MobileControlProvider>
  );
}

export default App
