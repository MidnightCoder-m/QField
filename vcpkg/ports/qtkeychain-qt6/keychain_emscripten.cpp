/******************************************************************************
 *   Copyright (C) 2026 by OPENGIS.ch <mohsen@opengis.ch>                     *
 *                                                                            *
 * This program is distributed in the hope that it will be useful, but        *
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY *
 * or FITNESS FOR A PARTICULAR PURPOSE. For licensing and distribution        *
 * details, check the accompanying file 'COPYING'.                            *
 *****************************************************************************/

#include "keychain_p.h"

using namespace QKeychain;

namespace
{
  // A browser has no credential store, and QGIS keeps its auth master password here.
  void refuse( Job *job )
  {
    job->emitFinishedWithError( NotImplemented, QObject::tr( "Keychain storage is not available in a browser" ) );
  }
} // namespace

void ReadPasswordJobPrivate::scheduledStart()
{
  refuse( q );
}

void WritePasswordJobPrivate::scheduledStart()
{
  refuse( q );
}

void DeletePasswordJobPrivate::scheduledStart()
{
  refuse( q );
}
