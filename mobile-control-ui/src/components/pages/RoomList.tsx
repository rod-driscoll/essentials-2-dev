import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useGetAllRooms } from '../../lib/store/rooms/rooms.hooks';

const RoomList = () => {
  const rooms = useGetAllRooms();
  const navigate = useNavigate();

  const entries = Object.entries(rooms);

  // Auto-navigate if there is exactly one room
  useEffect(() => {
    if (entries.length === 1) {
      navigate(`/room/${entries[0][0]}`, { replace: true });
    }
  }, [entries.length]);

  return (
    <div style={{ padding: '2rem', maxWidth: '600px', margin: '0 auto' }}>
      <h2 style={{ marginBottom: '1.5rem' }}>Select a Room</h2>
      {entries.length === 0 ? (
        <p style={{ color: '#888' }}>Connecting to processor...</p>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          {entries.map(([key, room]) => (
            <button
              key={key}
              onClick={() => navigate(`/room/${key}`)}
              style={{
                padding: '1rem 1.5rem',
                fontSize: '1rem',
                textAlign: 'left',
                cursor: 'pointer',
                borderRadius: '4px',
                border: '1px solid #444',
                background: '#222',
                color: '#fff',
              }}
            >
              {room.name ?? key}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

export default RoomList;