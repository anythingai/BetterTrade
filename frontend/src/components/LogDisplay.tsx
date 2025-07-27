import React, { useState, useMemo } from 'react';
// LogEntry type is used in the component logic
import { useNotifications } from '../contexts/NotificationContext';

interface LogDisplayProps {
  className?: string;
  maxEntries?: number;
}

export const LogDisplay: React.FC<LogDisplayProps> = ({ 
  className = '', 
  maxEntries = 100 
}) => {
  const { logs, clearLogs } = useNotifications();
  const [filterLevel, setFilterLevel] = useState<string>('all');
  const [filterAgent, setFilterAgent] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState<string>('');

  const filteredLogs = useMemo(() => {
    let filtered = logs;

    // Filter by level
    if (filterLevel !== 'all') {
      filtered = filtered.filter(log => log.level === filterLevel);
    }

    // Filter by agent
    if (filterAgent !== 'all') {
      filtered = filtered.filter(log => log.agent === filterAgent);
    }

    // Filter by search term
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      filtered = filtered.filter(log => 
        log.action.toLowerCase().includes(term) ||
        log.agent.toLowerCase().includes(term) ||
        (log.transaction_id && log.transaction_id.toLowerCase().includes(term)) ||
        JSON.stringify(log.details).toLowerCase().includes(term)
      );
    }

    // Sort by timestamp (newest first) and limit
    return filtered
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, maxEntries);
  }, [logs, filterLevel, filterAgent, searchTerm, maxEntries]);

  const uniqueAgents = useMemo(() => {
    const agents = new Set(logs.map(log => log.agent));
    return Array.from(agents).sort();
  }, [logs]);

  const getLevelIcon = (level: string): string => {
    switch (level) {
      case 'error':
        return '❌';
      case 'warn':
        return '⚠️';
      case 'info':
      default:
        return 'ℹ️';
    }
  };

  const formatTimestamp = (timestamp: number): string => {
    return new Date(timestamp).toLocaleString();
  };

  const formatDetails = (details: Record<string, unknown>): string => {
    return JSON.stringify(details, null, 2);
  };

  return (
    <div className={`log-display ${className}`}>
      <div className="log-display-header">
        <h3>System Logs</h3>
        <div className="log-controls">
          <div className="log-filters">
            <select 
              value={filterLevel} 
              onChange={(e) => setFilterLevel(e.target.value)}
              className="log-filter-select"
              aria-label="Filter by log level"
            >
              <option value="all">All Levels</option>
              <option value="info">Info</option>
              <option value="warn">Warning</option>
              <option value="error">Error</option>
            </select>

            <select 
              value={filterAgent} 
              onChange={(e) => setFilterAgent(e.target.value)}
              className="log-filter-select"
              aria-label="Filter by agent"
            >
              <option value="all">All Agents</option>
              {uniqueAgents.map(agent => (
                <option key={agent} value={agent}>{agent}</option>
              ))}
            </select>

            <input
              type="text"
              placeholder="Search logs..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="log-search-input"
            />
          </div>

          <button 
            type="button"
            onClick={clearLogs}
            className="log-clear-btn"
            disabled={logs.length === 0}
          >
            Clear Logs
          </button>
        </div>
      </div>

      <div className="log-entries">
        {filteredLogs.length === 0 ? (
          <div className="log-empty">
            {logs.length === 0 ? 'No log entries' : 'No entries match current filters'}
          </div>
        ) : (
          filteredLogs.map(log => (
            <div key={log.id} className={`log-entry log-${log.level}`}>
              <div className="log-entry-header">
                <span className="log-icon">{getLevelIcon(log.level)}</span>
                <span className="log-timestamp">{formatTimestamp(log.timestamp)}</span>
                <span className="log-agent">{log.agent}</span>
                <span className="log-action">{log.action}</span>
                {log.transaction_id && (
                  <span className="log-tx-id">
                    TX: <code>{log.transaction_id.substring(0, 8)}...</code>
                  </span>
                )}
              </div>
              
              {Object.keys(log.details).length > 0 && (
                <details className="log-details">
                  <summary>Details</summary>
                  <pre className="log-details-content">
                    {formatDetails(log.details)}
                  </pre>
                </details>
              )}
            </div>
          ))
        )}
      </div>

      <div className="log-display-footer">
        <span className="log-count">
          Showing {filteredLogs.length} of {logs.length} entries
        </span>
      </div>
    </div>
  );
};