import { useParams, useNavigate } from 'react-router-dom';
import { MainLayout } from '../../lib/shared/layout/habanero/MainLayout/MainLayout';
import {
  useRoomName,
  useRoomSourceList,
  useRoomIsOn,
  useRoomState,
} from '../../lib/store/rooms/rooms.hooks';
import { useIRunRouteAction } from '../../lib/shared/hooks/interfaces/useIRunRouteAction';
import { useIBasicVolumeWithFeedback } from '../../lib/shared/hooks/interfaces/useIBasicVolumeWithFeedback';

const RoomControl = () => {
  const { roomKey } = useParams<{ roomKey: string }>();
  const navigate = useNavigate();

  const name = useRoomName(roomKey!);
  const sourceList = useRoomSourceList(roomKey!);
  const isOn = useRoomIsOn(roomKey!);
  const room = useRoomState(roomKey!);

  // Use first available volume entry (commonly "master")
  const volumeEntries = Object.entries(room?.volumes ?? {});
  const masterVolume = volumeEntries.find(([k]) => k === 'master')?.[1] ?? volumeEntries[0]?.[1];

  const routeAction = useIRunRouteAction(roomKey!);
  const volume = useIBasicVolumeWithFeedback(`/room/${roomKey}`, masterVolume);

  const sources = sourceList
    ? Object.entries(sourceList)
        .filter(([, s]) => s.includeInSourceList)
        .sort(([, a], [, b]) => a.order - b.order)
    : [];

  const currentSourceKey = room?.selectedSourceKey;

  return (
    <MainLayout
      header={
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '1rem',
            padding: '0 1rem',
            height: '100%',
          }}
        >
          <button
            onClick={() => navigate('/')}
            style={{ background: 'none', border: '1px solid #666', color: '#fff', padding: '0.4rem 0.8rem', borderRadius: '4px', cursor: 'pointer' }}
          >
            ← Rooms
          </button>
          <span style={{ fontWeight: 600, fontSize: '1.1rem' }}>{name ?? roomKey}</span>
          <span style={{ marginLeft: 'auto', fontSize: '0.85rem', color: isOn ? '#4caf50' : '#888' }}>
            {isOn ? '● On' : '○ Off'}
          </span>
        </div>
      }
      content={
        <div style={{ padding: '1.5rem' }}>
          <h3 style={{ marginBottom: '1rem' }}>Sources</h3>
          {sources.length === 0 ? (
            <p style={{ color: '#888' }}>No sources configured</p>
          ) : (
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))',
                gap: '0.75rem',
              }}
            >
              {sources.map(([key, source]) => {
                const isSelected = currentSourceKey === key;
                return (
                  <button
                    key={key}
                    onClick={() => routeAction?.runRoute({ sourceListItemKey: key })}
                    style={{
                      padding: '1rem',
                      fontSize: '0.9rem',
                      cursor: 'pointer',
                      borderRadius: '6px',
                      border: isSelected ? '2px solid #2196f3' : '1px solid #444',
                      background: isSelected ? '#1565c0' : '#222',
                      color: '#fff',
                      textAlign: 'center',
                    }}
                  >
                    {source.preferredName || source.name || key}
                  </button>
                );
              })}
            </div>
          )}
        </div>
      }
      footer={
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
            padding: '0 1rem',
            height: '100%',
          }}
        >
          {volume && masterVolume ? (
            <>
              <button
                {...volume.volumeDown}
                style={{ padding: '0.5rem 1rem', fontSize: '1.1rem', cursor: 'pointer', borderRadius: '4px', border: '1px solid #444', background: '#333', color: '#fff' }}
              >
                −
              </button>
              <span style={{ minWidth: '2.5rem', textAlign: 'center', fontSize: '0.9rem' }}>
                {masterVolume.level}
                {masterVolume.units === 'Decibels' ? ' dB' : '%'}
              </span>
              <button
                {...volume.volumeUp}
                style={{ padding: '0.5rem 1rem', fontSize: '1.1rem', cursor: 'pointer', borderRadius: '4px', border: '1px solid #444', background: '#333', color: '#fff' }}
              >
                +
              </button>
              <button
                onClick={volume.muteToggle}
                style={{
                  padding: '0.5rem 0.75rem',
                  cursor: 'pointer',
                  borderRadius: '4px',
                  border: '1px solid #444',
                  background: masterVolume.muted ? '#c62828' : '#333',
                  color: '#fff',
                  fontSize: '1rem',
                }}
              >
                {masterVolume.muted ? 'Muted' : 'Mute'}
              </button>
            </>
          ) : (
            <span style={{ color: '#888', fontSize: '0.85rem' }}>Volume unavailable</span>
          )}
        </div>
      }
      volume={null}
      showVolume={false}
    />
  );
};

export default RoomControl;
