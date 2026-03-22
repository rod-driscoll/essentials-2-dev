import { useParams, useNavigate } from 'react-router-dom';
import { MainLayout } from '../../../lib/shared/layout/habanero/MainLayout/MainLayout';
import {
  useRoomName,
  useRoomSourceList,
} from '../../../lib/store/rooms/rooms.hooks';
import { useIRunRouteAction } from '../../../lib/shared/hooks/interfaces/useIRunRouteAction';
import { useRoomIBasicVolumeWithFeedback } from '../../../lib/shared/hooks/useRoomIBasicVolumeWithFeedback';
import { useIRunDefaultPresentRoute } from '../../../lib/shared/hooks/interfaces/useIRunDefaultPresentRoute';
import { useGetDevice } from '../../../lib/store/devices/devices.hooks';
import { DisplayState } from '../../../lib/types';

const HuddleRoomControl = () => {
  const { roomKey } = useParams<{ roomKey: string }>();
  const navigate = useNavigate();

  const name = useRoomName(roomKey!);
  const sourceList = useRoomSourceList(roomKey!);

  const routeAction = useIRunRouteAction(roomKey!);
  const volume = useRoomIBasicVolumeWithFeedback(roomKey!, 'master');
  const { runDefaultPresentRoute } = useIRunDefaultPresentRoute(roomKey!);
  const displayState = useGetDevice<DisplayState>('display-1');
  const displayIsOn = !!displayState?.powerState;

  const displayInputs = (displayState as any)?.inputs?.items as
    | Record<string, { key: string; name: string; isSelected: boolean }>
    | undefined;
  const selectedInputName = displayInputs
    ? Object.values(displayInputs).find(i => i.isSelected)?.name
    : undefined;
  const selectedSourceKey = selectedInputName && sourceList
    ? Object.entries(sourceList).find(([, s]) => s.name === selectedInputName)?.[0]
    : undefined;

  const sources = sourceList
    ? Object.entries(sourceList)
        .filter(([, s]) => s.includeInSourceList)
        .sort(([, a], [, b]) => a.order - b.order)
    : [];

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
            onClick={() => navigate('/mc/app/')}
            style={{ background: 'none', border: '1px solid #666', color: '#fff', padding: '0.4rem 0.8rem', borderRadius: '4px', cursor: 'pointer' }}
          >
            ← Rooms
          </button>
          <span style={{ fontWeight: 600, fontSize: '1.1rem' }}>{name ?? roomKey}</span>
          <span style={{ marginLeft: 'auto', fontSize: '0.85rem', color: displayIsOn ? '#4caf50' : '#888' }}>
            {displayIsOn ? '● On' : '○ Off'}
          </span>
        </div>
      }
      content={
        <div style={{ padding: '1.5rem', overflowY: 'auto', height: '100%', boxSizing: 'border-box' }}>
          <h3 style={{ marginBottom: '0.75rem' }}>Display</h3>
          <div style={{ display: 'flex', gap: '0.75rem', marginBottom: '2rem' }}>
            <button
              onClick={runDefaultPresentRoute}
              style={{
                padding: '0.75rem 1.5rem',
                fontSize: '0.9rem',
                cursor: 'pointer',
                borderRadius: '6px',
                border: displayIsOn ? '2px solid #4caf50' : '1px solid #444',
                background: displayIsOn ? '#1b5e20' : '#222',
                color: '#fff',
              }}
            >
              Power On
            </button>
            <button
              onClick={() => routeAction?.runRoute({ sourceListItemKey: 'roomOff' })}
              style={{
                padding: '0.75rem 1.5rem',
                fontSize: '0.9rem',
                cursor: 'pointer',
                borderRadius: '6px',
                border: !displayIsOn ? '2px solid #f44336' : '1px solid #444',
                background: !displayIsOn ? '#b71c1c' : '#222',
                color: '#fff',
              }}
            >
              Power Off
            </button>
          </div>

          <h3 style={{ marginBottom: '1rem' }}>Sources</h3>
          {sources.length === 0 ? (
            <p style={{ color: '#888' }}>No sources configured</p>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))', gap: '0.75rem', marginBottom: '2rem' }}>
              {sources.map(([key, source]) => {
                const isSelected = selectedSourceKey === key;
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

          <h3 style={{ marginBottom: '0.75rem' }}>Volume</h3>
          {volume ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <input
                  type="range"
                  min={0}
                  max={65535}
                  value={volume.volumeState.level}
                  onChange={(e) => volume.setLevel(Number(e.target.value))}
                  style={{ flex: 1, accentColor: '#2196f3', cursor: 'pointer' }}
                />
                <span style={{ minWidth: '3rem', textAlign: 'right', fontSize: '0.9rem', color: '#ccc' }}>
                  {`${Math.round(volume.volumeState.level / 65535 * 100)}%`}
                </span>
              </div>
              <div>
                <button
                  onClick={() => volume.muteToggle()}
                  style={{
                    padding: '0.6rem 1.2rem',
                    cursor: 'pointer',
                    borderRadius: '6px',
                    border: '1px solid #444',
                    background: volume.volumeState.muted ? '#c62828' : '#333',
                    color: '#fff',
                    fontSize: '0.9rem',
                  }}
                >
                  {volume.volumeState.muted ? 'Muted' : 'Mute'}
                </button>
              </div>
            </div>
          ) : (
            <p style={{ color: '#888', fontSize: '0.85rem' }}>Volume unavailable</p>
          )}
        </div>
      }
      footer={<div />}
      volume={null}
      showVolume={false}
    />
  );
};

export default HuddleRoomControl;
