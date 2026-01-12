// FILE: admin_portal/frontend/src/App.js
// VERSION: 1.0.0
// ROLE: Admin Portal Dashboard (React)

import React, { useEffect, useState } from 'react';

const Card = ({ title, value, sub }) => (
    <div style={{ background: '#1a1a1a', padding: '20px', borderRadius: '8px', border: '1px solid #333', minWidth: '200px' }}>
        <h3 style={{ color: '#888', fontSize: '12px', textTransform: 'uppercase' }}>{title}</h3>
        <div style={{ color: '#00ffc8', fontSize: '24px', fontWeight: 'bold', margin: '10px 0' }}>{value}</div>
        <div style={{ color: '#555', fontSize: '11px' }}>{sub}</div>
    </div>
);

function App() {
    const [velocity, setVelocity] = useState([]);

    useEffect(() => {
        // Poll the backend
        const interval = setInterval(() => {
            fetch('http://localhost:9000/api/analytics/velocity')
                .then(res => res.json())
                .then(data => setVelocity(data.sectors))
                .catch(err => console.error(err));
        }, 2000);
        return () => clearInterval(interval);
    }, []);

    return (
        <div style={{ background: '#000', minHeight: '100vh', color: '#fff', fontFamily: 'sans-serif', padding: '40px' }}>
            <header style={{ marginBottom: '40px', borderBottom: '1px solid #333', paddingBottom: '20px' }}>
                <h1 style={{ fontSize: '20px', letterSpacing: '2px' }}>SATYA SETU <span style={{ color: '#00ffc8' }}>COMMAND CENTER</span></h1>
                <div style={{ fontSize: '12px', color: '#666' }}>GOD MODE ACTIVE • TIER 4 ACCESS</div>
            </header>

            <section>
                <h2 style={{ fontSize: '14px', marginBottom: '20px' }}>NETWORK VELOCITY (TPS)</h2>
                <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>
                    {velocity.length > 0 ? velocity.map(s => (
                        <Card key={s.name} title={s.name} value={s.tps} sub={`Trend: ${s.trend.toUpperCase()}`} />
                    )) : <div style={{ color: '#444' }}>Connecting to Indexer...</div>}
                </div>
            </section>

            <section style={{ marginTop: '60px' }}>
                <h2 style={{ fontSize: '14px', marginBottom: '20px' }}>SYBIL DETECTION GRAPH</h2>
                <div style={{
                    width: '100%', height: '300px', background: '#0a0a0a',
                    border: '1px dashed #333', borderRadius: '8px',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#333'
                }}>
                    [ 3D FORCE GRAPH VISUALIZATION RENDERER ]
                </div>
            </section>
        </div>
    );
}

export default App;