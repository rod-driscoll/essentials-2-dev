import React from "react";
import { createRoot } from 'react-dom/client';
import {
  RouterProvider,
  createBrowserRouter,
} from 'react-router-dom';
import { MobileControlProvider } from '../../lib/shared/MobileControlProvider/MobileControlProvider';
import DualDisplayRoomBusiness from './DualDisplayRoomBusiness';
import { ErrorBox } from '../../lib';

const router = createBrowserRouter(
  [
    {
      path: '*',
      errorElement: <ErrorBox />,
      element: (
        <MobileControlProvider>
          <DualDisplayRoomBusiness />
        </MobileControlProvider>
      ),
    },
  ],
  {
    basename: '/mc/app',
  }
);

const container = document.getElementById('root');
if (!container) throw new Error('Cannot get root element. Check index.html');
const root = createRoot(container);
root.render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);
