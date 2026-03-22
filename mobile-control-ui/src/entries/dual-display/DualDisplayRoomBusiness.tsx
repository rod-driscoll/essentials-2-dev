import { Suspense, lazy } from "react";
import { Navigate, Route, Routes } from "react-router-dom";

const RoomList = lazy(() => import("../../components/pages/RoomList"));
const DualDisplayRoomControl = lazy(() => import("../../components/rooms/dual-display/DualDisplayRoomControl"));

const DualDisplayRoomBusiness = () => {
  return (
    <Suspense fallback={<div style={{ padding: '2rem', color: '#888' }}>Loading...</div>}>
      <Routes>
        <Route path="/" element={<RoomList />} />
        <Route path="/room/:roomKey/*" element={<DualDisplayRoomControl />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  );
};

export default DualDisplayRoomBusiness;
