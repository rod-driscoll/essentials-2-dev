import { useState } from 'react';
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

const DisplayCard = ({
  label,
  isOn,
}: {
  label: string;
  isOn: boolean;
}) => (
  <div
    style={{
      flex: 1,
      padding: '0.75rem 1rem',
      borderRadius: '6px',
      border: `1px solid ${isOn ? '#4caf50' : '#444'}`,
      background: isOn ? '#1b3a1f' : '#1a1a1a',
      display: 'flex',
      alignItems: 'center',
      gap: '0.5rem',
    }}
  >
    <span style={{ fontSize: '0.75rem', color: isOn ? '#4caf50' : '#666' }}>
      {isOn ? '●' : '○'}
    </span>
    <span style={{ fontSize: '0.85rem', color: isOn ? '#a5d6a7' : '#888' }}>{label}</span>
    <span style={{ marginLeft: 'auto', fontSize: '0.75rem', color: isOn ? '#4caf50' : '#666' }}>
      {isOn ? 'On' : 'Off'}
    </span>
  </div>
);

const DualDisplayRoomControl = () => {
  const { roomKey } = useParams<{ roomKey: string }>();
  const navigate = useNavigate();

  const name = useRoomName(roomKey!);
  const sourceList = useRoomSourceList(roomKey!);

  const routeAction = useIRunRouteAction(roomKey!);
  const volume = useRoomIBasicVolumeWithFeedback(roomKey!, 'master');
  const { runDefaultPresentRoute } = useIRunDefaultPresentRoute(roomKey!);

  const display1 = useGetDevice<DisplayState>('display-1');
  const display2 = useGetDevice<DisplayState>('display-2');
  const display1IsOn = !!display1?.powerState;
  const display2IsOn = !!display2?.powerState;
  const eitherOn = display1IsOn || display2IsOn;

  const [selectedSourceKey, setSelectedSourceKey] = useState<string | undefined>(undefined);

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
          <span style={{ marginLeft: 'auto', fontSize: '0.85rem', color: eitherOn ? '#4caf50' : '#888' }}>
            {eitherOn ? '● On' : '○ Off'}
          </span>
        </div>
      }
      content={
        <div style={{ padding: '1.5rem', overflowY: 'auto', height: '100%', boxSizing: 'border-box' }}>

          {/* Display status */}
          <h3 style={{ marginBottom: '0.75rem' }}>Displays</h3>
          <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem' }}>
            <DisplayCard label="Display 1" isOn={display1IsOn} />
            <DisplayCard label="Display 2" isOn={display2IsOn} />
          </div>

          {/* Power controls */}
          <div style={{ display: 'flex', gap: '0.75rem', marginBottom: '2rem' }}>
            <button
              onClick={runDefaultPresentRoute}
              style={{
                flex: 1,
                padding: '0.75rem 1rem',
                fontSize: '0.9rem',
                cursor: 'pointer',
                borderRadius: '6px',
                border: eitherOn ? '2px solid #4caf50' : '1px solid #444',
                background: eitherOn ? '#1b5e20' : '#222',
                color: '#fff',
              }}
            >
              Power On
            </button>
            <button
              onClick={() => { routeAction?.runRoute({ sourceListItemKey: 'roomOff' }); setSelectedSourceKey(undefined); }}
              style={{
                flex: 1,
                padding: '0.75rem 1rem',
                fontSize: '0.9rem',
                cursor: 'pointer',
                borderRadius: '6px',
                border: !eitherOn ? '2px solid #f44336' : '1px solid #444',
                background: !eitherOn ? '#b71c1c' : '#222',
                color: '#fff',
              }}
            >
              Power Off
            </button>
          </div>

          {/* Sources */}
          <h3 style={{ marginBottom: '1rem' }}>Sources</h3>
          {sources.length === 0 ? (
            <p style={{ color: '#888' }}>No sources configured</p>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))', gap: '0.75rem', marginBottom: '2rem' }}>
              {sources.map(([key, source]) => {
                const isSelected = currentSourceKey === key;
                return (
                  <button
                    key={key}
                    onClick={() => { routeAction?.runRoute({ sourceListItemKey: key }); setSelectedSourceKey(key); }}
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

          {/* Volume */}
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

export default DualDisplayRoomControl;
