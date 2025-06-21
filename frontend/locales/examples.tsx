// Example: Using namespaced translations

import React from 'react';
import { useTranslation } from './i18n';

// Example 1: Single namespace
export const SettingsPage: React.FC = () => {
  const { t } = useTranslation('settings');
  
  return (
    <div>
      <h1>{t('title')}</h1>
      <p>{t('subtitle')}</p>
      <button>{t('configure')}</button>
    </div>
  );
};

// Example 2: Multiple namespaces
export const UserProfilePage: React.FC = () => {
  const { t } = useTranslation(['profile', 'common']);
  
  return (
    <div>
      <h1>{t('profile:title')}</h1>
      <button>{t('common:save')}</button>
      <button>{t('common:cancel')}</button>
    </div>
  );
};

// Example 3: With default namespace
export const Dashboard: React.FC = () => {
  const { t } = useTranslation('dashboard');
  
  return (
    <div>
      <h1>{t('title')}</h1>
      <div>
        <span>{t('stats.totalUsers')}</span>
        <span>{t('stats.activePermissions')}</span>
      </div>
    </div>
  );
};

// Example 4: Accessing nested keys
export const PermissionsTable: React.FC = () => {
  const { t } = useTranslation('permissions');
  
  return (
    <table>
      <thead>
        <tr>
          <th>{t('table.headers.name')}</th>
          <th>{t('table.headers.status')}</th>
          <th>{t('table.headers.actions')}</th>
        </tr>
      </thead>
    </table>
  );
};
