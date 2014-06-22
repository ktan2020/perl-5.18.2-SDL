package SDL::ConfigData;
use strict;
my $arrayref = eval do {local $/; <DATA>}
  or die "Couldn't load ConfigData data: $@";
close DATA;
my ($config, $features, $auto_features) = @$arrayref;

sub config { $config->{$_[1]} }

sub set_config { $config->{$_[1]} = $_[2] }
sub set_feature { $features->{$_[1]} = 0+!!$_[2] }  # Constrain to 1 or 0

sub auto_feature_names { grep !exists $features->{$_}, keys %$auto_features }

sub feature_names {
  my @features = (keys %$features, auto_feature_names());
  @features;
}

sub config_names  { keys %$config }

sub write {
  my $me = __FILE__;

  # Can't use Module::Build::Dumper here because M::B is only a
  # build-time prereq of this module
  require Data::Dumper;

  my $mode_orig = (stat $me)[2] & 07777;
  chmod($mode_orig | 0222, $me); # Make it writeable
  open(my $fh, '+<', $me) or die "Can't rewrite $me: $!";
  seek($fh, 0, 0);
  while (<$fh>) {
    last if /^__DATA__$/;
  }
  die "Couldn't find __DATA__ token in $me" if eof($fh);

  seek($fh, tell($fh), 0);
  my $data = [$config, $features, $auto_features];
  print($fh 'do{ my '
	      . Data::Dumper->new([$data],['x'])->Purity(1)->Dump()
	      . '$x; }' );
  truncate($fh, tell($fh));
  close $fh;

  chmod($mode_orig, $me)
    or warn "Couldn't restore permissions on $me: $!";
}

sub feature {
  my ($package, $key) = @_;
  return $features->{$key} if exists $features->{$key};

  my $info = $auto_features->{$key} or return 0;

  # Under perl 5.005, each(%$foo) isn't working correctly when $foo
  # was reanimated with Data::Dumper and eval().  Not sure why, but
  # copying to a new hash seems to solve it.
  my %info = %$info;

  require Module::Build;  # XXX should get rid of this
  while (my ($type, $prereqs) = each %info) {
    next if $type eq 'description' || $type eq 'recommends';

    my %p = %$prereqs;  # Ditto here.
    while (my ($modname, $spec) = each %p) {
      my $status = Module::Build->check_installed_status($modname, $spec);
      if ((!$status->{ok}) xor ($type =~ /conflicts$/)) { return 0; }
      if ( ! eval "require $modname; 1" ) { return 0; }
    }
  }
  return 1;
}


=head1 NAME

SDL::ConfigData - Configuration for SDL

=head1 SYNOPSIS

  use SDL::ConfigData;
  $value = SDL::ConfigData->config('foo');
  $value = SDL::ConfigData->feature('bar');

  @names = SDL::ConfigData->config_names;
  @names = SDL::ConfigData->feature_names;

  SDL::ConfigData->set_config(foo => $new_value);
  SDL::ConfigData->set_feature(bar => $new_value);
  SDL::ConfigData->write;  # Save changes


=head1 DESCRIPTION

This module holds the configuration data for the C<SDL>
module.  It also provides a programmatic interface for getting or
setting that configuration data.  Note that in order to actually make
changes, you'll have to have write access to the C<SDL::ConfigData>
module, and you should attempt to understand the repercussions of your
actions.


=head1 METHODS

=over 4

=item config($name)

Given a string argument, returns the value of the configuration item
by that name, or C<undef> if no such item exists.

=item feature($name)

Given a string argument, returns the value of the feature by that
name, or C<undef> if no such feature exists.

=item set_config($name, $value)

Sets the configuration item with the given name to the given value.
The value may be any Perl scalar that will serialize correctly using
C<Data::Dumper>.  This includes references, objects (usually), and
complex data structures.  It probably does not include transient
things like filehandles or sockets.

=item set_feature($name, $value)

Sets the feature with the given name to the given boolean value.  The
value will be converted to 0 or 1 automatically.

=item config_names()

Returns a list of all the names of config items currently defined in
C<SDL::ConfigData>, or in scalar context the number of items.

=item feature_names()

Returns a list of all the names of features currently defined in
C<SDL::ConfigData>, or in scalar context the number of features.

=item auto_feature_names()

Returns a list of all the names of features whose availability is
dynamically determined, or in scalar context the number of such
features.  Does not include such features that have later been set to
a fixed value.

=item write()

Commits any changes from C<set_config()> and C<set_feature()> to disk.
Requires write access to the C<SDL::ConfigData> module.

=back


=head1 AUTHOR

C<SDL::ConfigData> was automatically created using C<Module::Build>.
C<Module::Build> was written by Ken Williams, but he holds no
authorship claim or copyright claim to the contents of C<SDL::ConfigData>.

=cut


__DATA__
do{ my $x = [
       {
         'subsystems' => {
                           'Video' => {
                                        'file' => {
                                                    'to' => 'lib/SDL/Video.xs',
                                                    'from' => 'src/Core/Video.xs'
                                                  },
                                        'libraries' => [
                                                         'SDL'
                                                       ]
                                      },
                           'Primitives' => {
                                             'libraries' => [
                                                              'SDL',
                                                              'SDL_gfx_primitives'
                                                            ],
                                             'file' => {
                                                         'from' => 'src/GFX/Primitives.xs',
                                                         'to' => 'lib/SDL/GFX/Primitives.xs'
                                                       }
                                           },
                           'SFont' => {
                                        'libraries' => [
                                                         'SDL',
                                                         'SDL_image'
                                                       ],
                                        'file' => {
                                                    'from' => 'src/SDLx/SFont.xs',
                                                    'to' => 'lib/SDLx/SFont.xs'
                                                  }
                                      },
                           'ValidateX' => {
                                            'libraries' => [
                                                             'SDL'
                                                           ],
                                            'file' => {
                                                        'from' => 'src/SDLx/Validate.xs',
                                                        'to' => 'lib/SDLx/Validate.xs'
                                                      }
                                          },
                           'Joystick' => {
                                           'file' => {
                                                       'from' => 'src/Core/Joystick.xs',
                                                       'to' => 'lib/SDL/Joystick.xs'
                                                     },
                                           'libraries' => [
                                                            'SDL'
                                                          ]
                                         },
                           'StateX' => {
                                         'file' => {
                                                     'to' => 'lib/SDLx/Controller/State.xs',
                                                     'from' => 'src/SDLx/Controller/State.xs'
                                                   },
                                         'libraries' => [
                                                          'SDL'
                                                        ]
                                       },
                           'CDTrack' => {
                                          'libraries' => [
                                                           'SDL'
                                                         ],
                                          'file' => {
                                                      'from' => 'src/Core/objects/CDTrack.xs',
                                                      'to' => 'lib/SDL/CDTrack.xs'
                                                    }
                                        },
                           'Mixer' => {
                                        'libraries' => [
                                                         'SDL',
                                                         'SDL_mixer'
                                                       ],
                                        'file' => {
                                                    'to' => 'lib/SDL/Mixer.xs',
                                                    'from' => 'src/Mixer/Mixer.xs'
                                                  }
                                      },
                           'MixMusic' => {
                                           'libraries' => [
                                                            'SDL',
                                                            'SDL_mixer'
                                                          ],
                                           'file' => {
                                                       'from' => 'src/Mixer/objects/MixMusic.xs',
                                                       'to' => 'lib/SDL/Mixer/MixMusic.xs'
                                                     }
                                         },
                           'TTF_Font' => {
                                           'file' => {
                                                       'from' => 'src/TTF/objects/Font.xs',
                                                       'to' => 'lib/SDL/TTF/Font.xs'
                                                     },
                                           'libraries' => [
                                                            'SDL',
                                                            'SDL_ttf'
                                                          ]
                                         },
                           'MixerEffects' => {
                                               'file' => {
                                                           'from' => 'src/Mixer/Effects.xs',
                                                           'to' => 'lib/SDL/Mixer/Effects.xs'
                                                         },
                                               'libraries' => [
                                                                'SDL',
                                                                'SDL_mixer'
                                                              ]
                                             },
                           'Event' => {
                                        'libraries' => [
                                                         'SDL'
                                                       ],
                                        'file' => {
                                                    'to' => 'lib/SDL/Event.xs',
                                                    'from' => 'src/Core/objects/Event.xs'
                                                  }
                                      },
                           'Audio' => {
                                        'file' => {
                                                    'to' => 'lib/SDL/Audio.xs',
                                                    'from' => 'src/Core/Audio.xs'
                                                  },
                                        'libraries' => [
                                                         'SDL'
                                                       ]
                                      },
                           'LayerX' => {
                                         'libraries' => [
                                                          'SDL',
                                                          'SDL_image'
                                                        ],
                                         'file' => {
                                                     'to' => 'lib/SDLx/Layer.xs',
                                                     'from' => 'src/SDLx/Layer.xs'
                                                   }
                                       },
                           'MixerChannels' => {
                                                'libraries' => [
                                                                 'SDL',
                                                                 'SDL_mixer'
                                                               ],
                                                'file' => {
                                                            'from' => 'src/Mixer/Channels.xs',
                                                            'to' => 'lib/SDL/Mixer/Channels.xs'
                                                          }
                                              },
                           'MultiThread' => {
                                              'file' => {
                                                          'from' => 'src/Core/MultiThread.xs',
                                                          'to' => 'lib/SDL/MultiThread.xs'
                                                        },
                                              'libraries' => [
                                                               'SDL'
                                                             ]
                                            },
                           'FPSManager' => {
                                             'file' => {
                                                         'from' => 'src/GFX/FPSManager.xs',
                                                         'to' => 'lib/SDL/GFX/FPSManager.xs'
                                                       },
                                             'libraries' => [
                                                              'SDL',
                                                              'SDL_gfx_framerate'
                                                            ]
                                           },
                           'Context' => {
                                          'libraries' => [
                                                           'SDL',
                                                           'SDL_Pango'
                                                         ],
                                          'file' => {
                                                      'from' => 'src/Pango/objects/Context.xs',
                                                      'to' => 'lib/SDL/Pango/Context.xs'
                                                    }
                                        },
                           'LayerManagerX' => {
                                                'libraries' => [
                                                                 'SDL'
                                                               ],
                                                'file' => {
                                                            'from' => 'src/SDLx/LayerManager.xs',
                                                            'to' => 'lib/SDLx/LayerManager.xs'
                                                          }
                                              },
                           'SurfaceX' => {
                                           'libraries' => [
                                                            'SDL',
                                                            'SDL_gfx_primitives'
                                                          ],
                                           'file' => {
                                                       'from' => 'src/SDLx/Surface.xs',
                                                       'to' => 'lib/SDLx/Surface.xs'
                                                     }
                                         },
                           'Version' => {
                                          'libraries' => [
                                                           'SDL'
                                                         ],
                                          'file' => {
                                                      'from' => 'src/Core/objects/Version.xs',
                                                      'to' => 'lib/SDL/Version.xs'
                                                    }
                                        },
                           'RWOps' => {
                                        'libraries' => [
                                                         'SDL'
                                                       ],
                                        'file' => {
                                                    'from' => 'src/Core/objects/RWOps.xs',
                                                    'to' => 'lib/SDL/RWOps.xs'
                                                  }
                                      },
                           'Overlay' => {
                                          'file' => {
                                                      'from' => 'src/Core/objects/Overlay.xs',
                                                      'to' => 'lib/SDL/Overlay.xs'
                                                    },
                                          'libraries' => [
                                                           'SDL'
                                                         ]
                                        },
                           'Palette' => {
                                          'libraries' => [
                                                           'SDL'
                                                         ],
                                          'file' => {
                                                      'to' => 'lib/SDL/Palette.xs',
                                                      'from' => 'src/Core/objects/Palette.xs'
                                                    }
                                        },
                           'Color' => {
                                        'libraries' => [
                                                         'SDL'
                                                       ],
                                        'file' => {
                                                    'to' => 'lib/SDL/Color.xs',
                                                    'from' => 'src/Core/objects/Color.xs'
                                                  }
                                      },
                           'Surface' => {
                                          'file' => {
                                                      'to' => 'lib/SDL/Surface.xs',
                                                      'from' => 'src/Core/objects/Surface.xs'
                                                    },
                                          'libraries' => [
                                                           'SDL'
                                                         ]
                                        },
                           'SDL' => {
                                      'file' => {
                                                  'from' => 'src/SDL.xs',
                                                  'to' => 'lib/SDL_perl.xs'
                                                },
                                      'libraries' => [
                                                       'SDL'
                                                     ]
                                    },
                           'Framerate' => {
                                            'libraries' => [
                                                             'SDL',
                                                             'SDL_gfx_framerate'
                                                           ],
                                            'file' => {
                                                        'to' => 'lib/SDL/GFX/Framerate.xs',
                                                        'from' => 'src/GFX/Framerate.xs'
                                                      }
                                          },
                           'MixerMusic' => {
                                             'file' => {
                                                         'from' => 'src/Mixer/Music.xs',
                                                         'to' => 'lib/SDL/Mixer/Music.xs'
                                                       },
                                             'libraries' => [
                                                              'SDL',
                                                              'SDL_mixer'
                                                            ]
                                           },
                           'Pango' => {
                                        'file' => {
                                                    'to' => 'lib/SDL/Pango.xs',
                                                    'from' => 'src/Pango/Pango.xs'
                                                  },
                                        'libraries' => [
                                                         'SDL',
                                                         'SDL_Pango'
                                                       ]
                                      },
                           'Cursor' => {
                                         'file' => {
                                                     'from' => 'src/Core/objects/Cursor.xs',
                                                     'to' => 'lib/SDL/Cursor.xs'
                                                   },
                                         'libraries' => [
                                                          'SDL'
                                                        ]
                                       },
                           'Time' => {
                                       'libraries' => [
                                                        'SDL'
                                                      ],
                                       'file' => {
                                                   'to' => 'lib/SDL/Time.xs',
                                                   'from' => 'src/Core/Time.xs'
                                                 }
                                     },
                           'Mouse' => {
                                        'file' => {
                                                    'from' => 'src/Core/Mouse.xs',
                                                    'to' => 'lib/SDL/Mouse.xs'
                                                  },
                                        'libraries' => [
                                                         'SDL'
                                                       ]
                                      },
                           'InterfaceX' => {
                                             'libraries' => [
                                                              'SDL'
                                                            ],
                                             'file' => {
                                                         'to' => 'lib/SDLx/Controller/Interface.xs',
                                                         'from' => 'src/SDLx/Controller/Interface.xs'
                                                       }
                                           },
                           'TimerX' => {
                                         'file' => {
                                                     'from' => 'src/SDLx/Timer.xs',
                                                     'to' => 'lib/SDLx/Controller/Timer.xs'
                                                   },
                                         'libraries' => [
                                                          'SDL'
                                                        ]
                                       },
                           'MixerGroups' => {
                                              'libraries' => [
                                                               'SDL',
                                                               'SDL_mixer'
                                                             ],
                                              'file' => {
                                                          'to' => 'lib/SDL/Mixer/Groups.xs',
                                                          'from' => 'src/Mixer/Groups.xs'
                                                        }
                                            },
                           'TTF' => {
                                      'libraries' => [
                                                       'SDL',
                                                       'SDL_ttf'
                                                     ],
                                      'file' => {
                                                  'to' => 'lib/SDL/TTF.xs',
                                                  'from' => 'src/TTF/TTF.xs'
                                                }
                                    },
                           'MixerSamples' => {
                                               'file' => {
                                                           'from' => 'src/Mixer/Samples.xs',
                                                           'to' => 'lib/SDL/Mixer/Samples.xs'
                                                         },
                                               'libraries' => [
                                                                'SDL',
                                                                'SDL_mixer'
                                                              ]
                                             },
                           'CD' => {
                                     'libraries' => [
                                                      'SDL'
                                                    ],
                                     'file' => {
                                                 'from' => 'src/Core/objects/CD.xs',
                                                 'to' => 'lib/SDL/CD.xs'
                                               }
                                   },
                           'Image' => {
                                        'file' => {
                                                    'from' => 'src/Image.xs',
                                                    'to' => 'lib/SDL/Image.xs'
                                                  },
                                        'libraries' => [
                                                         'SDL',
                                                         'SDL_image'
                                                       ]
                                      },
                           'ImageFilter' => {
                                              'file' => {
                                                          'to' => 'lib/SDL/GFX/ImageFilter.xs',
                                                          'from' => 'src/GFX/ImageFilter.xs'
                                                        },
                                              'libraries' => [
                                                               'SDL',
                                                               'SDL_gfx_imagefilter'
                                                             ]
                                            },
                           'PixelFormat' => {
                                              'libraries' => [
                                                               'SDL'
                                                             ],
                                              'file' => {
                                                          'to' => 'lib/SDL/PixelFormat.xs',
                                                          'from' => 'src/Core/objects/PixelFormat.xs'
                                                        }
                                            },
                           'Events' => {
                                         'libraries' => [
                                                          'SDL'
                                                        ],
                                         'file' => {
                                                     'from' => 'src/Core/Events.xs',
                                                     'to' => 'lib/SDL/Events.xs'
                                                   }
                                       },
                           'Rotozoom' => {
                                           'file' => {
                                                       'to' => 'lib/SDL/GFX/Rotozoom.xs',
                                                       'from' => 'src/GFX/Rotozoom.xs'
                                                     },
                                           'libraries' => [
                                                            'SDL',
                                                            'SDL_gfx_rotozoom'
                                                          ]
                                         },
                           'Rect' => {
                                       'libraries' => [
                                                        'SDL'
                                                      ],
                                       'file' => {
                                                   'from' => 'src/Core/objects/Rect.xs',
                                                   'to' => 'lib/SDL/Rect.xs'
                                                 }
                                     },
                           'BlitFunc' => {
                                           'libraries' => [
                                                            'SDL',
                                                            'SDL_gfx_blitfunc'
                                                          ],
                                           'file' => {
                                                       'from' => 'src/GFX/BlitFunc.xs',
                                                       'to' => 'lib/SDL/GFX/BlitFunc.xs'
                                                     }
                                         },
                           'AudioCVT' => {
                                           'file' => {
                                                       'from' => 'src/Core/objects/AudioCVT.xs',
                                                       'to' => 'lib/SDL/AudioCVT.xs'
                                                     },
                                           'libraries' => [
                                                            'SDL'
                                                          ]
                                         },
                           'GFX' => {
                                      'libraries' => [
                                                       'SDL',
                                                       'SDL_gfx_primitives'
                                                     ],
                                      'file' => {
                                                  'from' => 'src/GFX/GFX.xs',
                                                  'to' => 'lib/SDL/GFX.xs'
                                                }
                                    },
                           'VideoInfo' => {
                                            'libraries' => [
                                                             'SDL'
                                                           ],
                                            'file' => {
                                                        'from' => 'src/Core/objects/VideoInfo.xs',
                                                        'to' => 'lib/SDL/VideoInfo.xs'
                                                      }
                                          },
                           'CDROM' => {
                                        'libraries' => [
                                                         'SDL'
                                                       ],
                                        'file' => {
                                                    'from' => 'src/Core/CDROM.xs',
                                                    'to' => 'lib/SDL/CDROM.xs'
                                                  }
                                      },
                           'MixChunk' => {
                                           'file' => {
                                                       'to' => 'lib/SDL/Mixer/MixChunk.xs',
                                                       'from' => 'src/Mixer/objects/MixChunk.xs'
                                                     },
                                           'libraries' => [
                                                            'SDL',
                                                            'SDL_mixer'
                                                          ]
                                         },
                           'AudioSpec' => {
                                            'libraries' => [
                                                             'SDL'
                                                           ],
                                            'file' => {
                                                        'to' => 'lib/SDL/AudioSpec.xs',
                                                        'from' => 'src/Core/objects/AudioSpec.xs'
                                                      }
                                          }
                         },
         'SDL_cfg' => {
                        'Rotozoom' => {
                                        'links' => [
                                                     '-lSDL',
                                                     '-lSDL_gfx'
                                                   ],
                                        'libs' => {
                                                    'SDL_gfx_rotozoom' => 1,
                                                    'SDL' => 1
                                                  },
                                        'defines' => [
                                                       '-DHAVE_SDL',
                                                       '-DHAVE_SDL_GFX_ROTOZOOM'
                                                     ]
                                      },
                        'Events' => {
                                      'defines' => [
                                                     '-DHAVE_SDL'
                                                   ],
                                      'links' => [
                                                   '-lSDL'
                                                 ],
                                      'libs' => {
                                                  'SDL' => 1
                                                }
                                    },
                        'Rect' => {
                                    'links' => [
                                                 '-lSDL'
                                               ],
                                    'libs' => {
                                                'SDL' => 1
                                              },
                                    'defines' => [
                                                   '-DHAVE_SDL'
                                                 ]
                                  },
                        'BlitFunc' => {
                                        'defines' => [
                                                       '-DHAVE_SDL',
                                                       '-DHAVE_SDL_GFX_BLITFUNC'
                                                     ],
                                        'links' => [
                                                     '-lSDL',
                                                     '-lSDL_gfx'
                                                   ],
                                        'libs' => {
                                                    'SDL' => 1,
                                                    'SDL_gfx_blitfunc' => 1
                                                  }
                                      },
                        'VideoInfo' => {
                                         'links' => [
                                                      '-lSDL'
                                                    ],
                                         'libs' => {
                                                     'SDL' => 1
                                                   },
                                         'defines' => [
                                                        '-DHAVE_SDL'
                                                      ]
                                       },
                        'AudioCVT' => {
                                        'defines' => [
                                                       '-DHAVE_SDL'
                                                     ],
                                        'libs' => {
                                                    'SDL' => 1
                                                  },
                                        'links' => [
                                                     '-lSDL'
                                                   ]
                                      },
                        'GFX' => {
                                   'libs' => {
                                               'SDL' => 1,
                                               'SDL_gfx_primitives' => 1
                                             },
                                   'links' => [
                                                '-lSDL',
                                                '-lSDL_gfx'
                                              ],
                                   'defines' => [
                                                  '-DHAVE_SDL',
                                                  '-DHAVE_SDL_GFX_PRIMITIVES'
                                                ]
                                 },
                        'MixChunk' => {
                                        'links' => [
                                                     '-lSDL',
                                                     '-lSDL_mixer'
                                                   ],
                                        'libs' => {
                                                    'SDL' => 1,
                                                    'SDL_mixer' => 1
                                                  },
                                        'defines' => [
                                                       '-DHAVE_SDL',
                                                       '-DHAVE_SDL_MIXER'
                                                     ]
                                      },
                        'AudioSpec' => {
                                         'defines' => [
                                                        '-DHAVE_SDL'
                                                      ],
                                         'libs' => {
                                                     'SDL' => 1
                                                   },
                                         'links' => [
                                                      '-lSDL'
                                                    ]
                                       },
                        'CDROM' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   },
                        'Time' => {
                                    'libs' => {
                                                'SDL' => 1
                                              },
                                    'links' => [
                                                 '-lSDL'
                                               ],
                                    'defines' => [
                                                   '-DHAVE_SDL'
                                                 ]
                                  },
                        'Mouse' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   },
                        'Framerate' => {
                                         'defines' => [
                                                        '-DHAVE_SDL',
                                                        '-DHAVE_SDL_GFX_FRAMERATE'
                                                      ],
                                         'libs' => {
                                                     'SDL' => 1,
                                                     'SDL_gfx_framerate' => 1
                                                   },
                                         'links' => [
                                                      '-lSDL',
                                                      '-lSDL_gfx'
                                                    ]
                                       },
                        'Cursor' => {
                                      'links' => [
                                                   '-lSDL'
                                                 ],
                                      'libs' => {
                                                  'SDL' => 1
                                                },
                                      'defines' => [
                                                     '-DHAVE_SDL'
                                                   ]
                                    },
                        'MixerMusic' => {
                                          'libs' => {
                                                      'SDL_mixer' => 1,
                                                      'SDL' => 1
                                                    },
                                          'links' => [
                                                       '-lSDL',
                                                       '-lSDL_mixer'
                                                     ],
                                          'defines' => [
                                                         '-DHAVE_SDL',
                                                         '-DHAVE_SDL_MIXER'
                                                       ]
                                        },
                        'Pango' => {
                                     'libs' => {
                                                 'SDL' => 1,
                                                 'SDL_Pango' => 1
                                               },
                                     'links' => [
                                                  '-lSDL',
                                                  '-lSDL_Pango'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL',
                                                    '-DHAVE_SDL_PANGO'
                                                  ]
                                   },
                        'InterfaceX' => {
                                          'libs' => {
                                                      'SDL' => 1
                                                    },
                                          'links' => [
                                                       '-lSDL'
                                                     ],
                                          'defines' => [
                                                         '-DHAVE_SDL'
                                                       ]
                                        },
                        'TimerX' => {
                                      'libs' => {
                                                  'SDL' => 1
                                                },
                                      'links' => [
                                                   '-lSDL'
                                                 ],
                                      'defines' => [
                                                     '-DHAVE_SDL'
                                                   ]
                                    },
                        'MixerSamples' => {
                                            'links' => [
                                                         '-lSDL',
                                                         '-lSDL_mixer'
                                                       ],
                                            'libs' => {
                                                        'SDL' => 1,
                                                        'SDL_mixer' => 1
                                                      },
                                            'defines' => [
                                                           '-DHAVE_SDL',
                                                           '-DHAVE_SDL_MIXER'
                                                         ]
                                          },
                        'MixerGroups' => {
                                           'libs' => {
                                                       'SDL_mixer' => 1,
                                                       'SDL' => 1
                                                     },
                                           'links' => [
                                                        '-lSDL',
                                                        '-lSDL_mixer'
                                                      ],
                                           'defines' => [
                                                          '-DHAVE_SDL',
                                                          '-DHAVE_SDL_MIXER'
                                                        ]
                                         },
                        'TTF' => {
                                   'defines' => [
                                                  '-DHAVE_SDL',
                                                  '-DHAVE_SDL_TTF'
                                                ],
                                   'libs' => {
                                               'SDL' => 1,
                                               'SDL_ttf' => 1
                                             },
                                   'links' => [
                                                '-lSDL',
                                                '-lSDL_ttf'
                                              ]
                                 },
                        'ImageFilter' => {
                                           'defines' => [
                                                          '-DHAVE_SDL',
                                                          '-DHAVE_SDL_GFX_IMAGEFILTER'
                                                        ],
                                           'libs' => {
                                                       'SDL_gfx_imagefilter' => 1,
                                                       'SDL' => 1
                                                     },
                                           'links' => [
                                                        '-lSDL',
                                                        '-lSDL_gfx'
                                                      ]
                                         },
                        'PixelFormat' => {
                                           'defines' => [
                                                          '-DHAVE_SDL'
                                                        ],
                                           'libs' => {
                                                       'SDL' => 1
                                                     },
                                           'links' => [
                                                        '-lSDL'
                                                      ]
                                         },
                        'CD' => {
                                  'links' => [
                                               '-lSDL'
                                             ],
                                  'libs' => {
                                              'SDL' => 1
                                            },
                                  'defines' => [
                                                 '-DHAVE_SDL'
                                               ]
                                },
                        'Image' => {
                                     'links' => [
                                                  '-lSDL',
                                                  '-lSDL_image'
                                                ],
                                     'libs' => {
                                                 'SDL' => 1,
                                                 'SDL_image' => 1
                                               },
                                     'defines' => [
                                                    '-DHAVE_SDL',
                                                    '-DHAVE_SDL_IMAGE'
                                                  ]
                                   },
                        'Context' => {
                                       'defines' => [
                                                      '-DHAVE_SDL',
                                                      '-DHAVE_SDL_PANGO'
                                                    ],
                                       'libs' => {
                                                   'SDL_Pango' => 1,
                                                   'SDL' => 1
                                                 },
                                       'links' => [
                                                    '-lSDL',
                                                    '-lSDL_Pango'
                                                  ]
                                     },
                        'MultiThread' => {
                                           'libs' => {
                                                       'SDL' => 1
                                                     },
                                           'links' => [
                                                        '-lSDL'
                                                      ],
                                           'defines' => [
                                                          '-DHAVE_SDL'
                                                        ]
                                         },
                        'FPSManager' => {
                                          'defines' => [
                                                         '-DHAVE_SDL',
                                                         '-DHAVE_SDL_GFX_FRAMERATE'
                                                       ],
                                          'libs' => {
                                                      'SDL' => 1,
                                                      'SDL_gfx_framerate' => 1
                                                    },
                                          'links' => [
                                                       '-lSDL',
                                                       '-lSDL_gfx'
                                                     ]
                                        },
                        'RWOps' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   },
                        'Overlay' => {
                                       'links' => [
                                                    '-lSDL'
                                                  ],
                                       'libs' => {
                                                   'SDL' => 1
                                                 },
                                       'defines' => [
                                                      '-DHAVE_SDL'
                                                    ]
                                     },
                        'Palette' => {
                                       'defines' => [
                                                      '-DHAVE_SDL'
                                                    ],
                                       'links' => [
                                                    '-lSDL'
                                                  ],
                                       'libs' => {
                                                   'SDL' => 1
                                                 }
                                     },
                        'Color' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   },
                        'LayerManagerX' => {
                                             'libs' => {
                                                         'SDL' => 1
                                                       },
                                             'links' => [
                                                          '-lSDL'
                                                        ],
                                             'defines' => [
                                                            '-DHAVE_SDL'
                                                          ]
                                           },
                        'SurfaceX' => {
                                        'links' => [
                                                     '-lSDL',
                                                     '-lSDL_gfx'
                                                   ],
                                        'libs' => {
                                                    'SDL_gfx_primitives' => 1,
                                                    'SDL' => 1
                                                  },
                                        'defines' => [
                                                       '-DHAVE_SDL',
                                                       '-DHAVE_SDL_GFX_PRIMITIVES'
                                                     ]
                                      },
                        'Version' => {
                                       'links' => [
                                                    '-lSDL'
                                                  ],
                                       'libs' => {
                                                   'SDL' => 1
                                                 },
                                       'defines' => [
                                                      '-DHAVE_SDL'
                                                    ]
                                     },
                        'SDL' => {
                                   'defines' => [
                                                  '-DHAVE_SDL'
                                                ],
                                   'links' => [
                                                '-lSDL'
                                              ],
                                   'libs' => {
                                               'SDL' => 1
                                             }
                                 },
                        'Surface' => {
                                       'defines' => [
                                                      '-DHAVE_SDL'
                                                    ],
                                       'libs' => {
                                                   'SDL' => 1
                                                 },
                                       'links' => [
                                                    '-lSDL'
                                                  ]
                                     },
                        'SFont' => {
                                     'libs' => {
                                                 'SDL' => 1,
                                                 'SDL_image' => 1
                                               },
                                     'links' => [
                                                  '-lSDL',
                                                  '-lSDL_image'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL',
                                                    '-DHAVE_SDL_IMAGE'
                                                  ]
                                   },
                        'Video' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   },
                        'Primitives' => {
                                          'defines' => [
                                                         '-DHAVE_SDL',
                                                         '-DHAVE_SDL_GFX_PRIMITIVES'
                                                       ],
                                          'links' => [
                                                       '-lSDL',
                                                       '-lSDL_gfx'
                                                     ],
                                          'libs' => {
                                                      'SDL' => 1,
                                                      'SDL_gfx_primitives' => 1
                                                    }
                                        },
                        'CDTrack' => {
                                       'libs' => {
                                                   'SDL' => 1
                                                 },
                                       'links' => [
                                                    '-lSDL'
                                                  ],
                                       'defines' => [
                                                      '-DHAVE_SDL'
                                                    ]
                                     },
                        'ValidateX' => {
                                         'defines' => [
                                                        '-DHAVE_SDL'
                                                      ],
                                         'libs' => {
                                                     'SDL' => 1
                                                   },
                                         'links' => [
                                                      '-lSDL'
                                                    ]
                                       },
                        'Joystick' => {
                                        'links' => [
                                                     '-lSDL'
                                                   ],
                                        'libs' => {
                                                    'SDL' => 1
                                                  },
                                        'defines' => [
                                                       '-DHAVE_SDL'
                                                     ]
                                      },
                        'StateX' => {
                                      'defines' => [
                                                     '-DHAVE_SDL'
                                                   ],
                                      'libs' => {
                                                  'SDL' => 1
                                                },
                                      'links' => [
                                                   '-lSDL'
                                                 ]
                                    },
                        'MixerEffects' => {
                                            'defines' => [
                                                           '-DHAVE_SDL',
                                                           '-DHAVE_SDL_MIXER'
                                                         ],
                                            'links' => [
                                                         '-lSDL',
                                                         '-lSDL_mixer'
                                                       ],
                                            'libs' => {
                                                        'SDL_mixer' => 1,
                                                        'SDL' => 1
                                                      }
                                          },
                        'TTF_Font' => {
                                        'links' => [
                                                     '-lSDL',
                                                     '-lSDL_ttf'
                                                   ],
                                        'libs' => {
                                                    'SDL' => 1,
                                                    'SDL_ttf' => 1
                                                  },
                                        'defines' => [
                                                       '-DHAVE_SDL',
                                                       '-DHAVE_SDL_TTF'
                                                     ]
                                      },
                        'MixMusic' => {
                                        'defines' => [
                                                       '-DHAVE_SDL',
                                                       '-DHAVE_SDL_MIXER'
                                                     ],
                                        'libs' => {
                                                    'SDL' => 1,
                                                    'SDL_mixer' => 1
                                                  },
                                        'links' => [
                                                     '-lSDL',
                                                     '-lSDL_mixer'
                                                   ]
                                      },
                        'Mixer' => {
                                     'defines' => [
                                                    '-DHAVE_SDL',
                                                    '-DHAVE_SDL_MIXER'
                                                  ],
                                     'links' => [
                                                  '-lSDL',
                                                  '-lSDL_mixer'
                                                ],
                                     'libs' => {
                                                 'SDL' => 1,
                                                 'SDL_mixer' => 1
                                               }
                                   },
                        'LayerX' => {
                                      'defines' => [
                                                     '-DHAVE_SDL',
                                                     '-DHAVE_SDL_IMAGE'
                                                   ],
                                      'links' => [
                                                   '-lSDL',
                                                   '-lSDL_image'
                                                 ],
                                      'libs' => {
                                                  'SDL' => 1,
                                                  'SDL_image' => 1
                                                }
                                    },
                        'MixerChannels' => {
                                             'links' => [
                                                          '-lSDL',
                                                          '-lSDL_mixer'
                                                        ],
                                             'libs' => {
                                                         'SDL_mixer' => 1,
                                                         'SDL' => 1
                                                       },
                                             'defines' => [
                                                            '-DHAVE_SDL',
                                                            '-DHAVE_SDL_MIXER'
                                                          ]
                                           },
                        'Event' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   },
                        'Audio' => {
                                     'libs' => {
                                                 'SDL' => 1
                                               },
                                     'links' => [
                                                  '-lSDL'
                                                ],
                                     'defines' => [
                                                    '-DHAVE_SDL'
                                                  ]
                                   }
                      },
         'SDL_lib_translate' => {
                                  'SDL::Mixer' => [
                                                    'SDL',
                                                    'SDL_mixer'
                                                  ],
                                  'SDL::Joystick' => [
                                                       'SDL'
                                                     ],
                                  'SDL::Mixer::Effects' => [
                                                             'SDL',
                                                             'SDL_mixer'
                                                           ],
                                  'SDLx::SFont' => [
                                                     'SDL',
                                                     'SDL_image'
                                                   ],
                                  'SDL::CD' => [
                                                 'SDL'
                                               ],
                                  'SDL::Mixer::Samples' => [
                                                             'SDL',
                                                             'SDL_mixer'
                                                           ],
                                  'SDL::TTF::Font' => [
                                                        'SDL',
                                                        'SDL_ttf'
                                                      ],
                                  'SDLx::Controller::State' => [
                                                                 'SDL'
                                                               ],
                                  'SDL::RWOps' => [
                                                    'SDL'
                                                  ],
                                  'SDL::GFX::BlitFunc' => [
                                                            'SDL',
                                                            'SDL_gfx'
                                                          ],
                                  'SDL::GFX::Primitives' => [
                                                              'SDL',
                                                              'SDL_gfx'
                                                            ],
                                  'SDLx::Controller::Timer' => [
                                                                 'SDL'
                                                               ],
                                  'SDL::CDROM' => [
                                                    'SDL'
                                                  ],
                                  'SDL::VideoInfo' => [
                                                        'SDL'
                                                      ],
                                  'SDL_perl' => [
                                                  'SDL'
                                                ],
                                  'SDL::GFX::ImageFilter' => [
                                                               'SDL',
                                                               'SDL_gfx'
                                                             ],
                                  'SDL::Palette' => [
                                                      'SDL'
                                                    ],
                                  'SDL::AudioCVT' => [
                                                       'SDL'
                                                     ],
                                  'SDL::Mixer::Music' => [
                                                           'SDL',
                                                           'SDL_mixer'
                                                         ],
                                  'SDL::Pango' => [
                                                    'SDL',
                                                    'SDL_Pango'
                                                  ],
                                  'SDL::Mixer::Channels' => [
                                                              'SDL',
                                                              'SDL_mixer'
                                                            ],
                                  'SDL::MultiThread' => [
                                                          'SDL'
                                                        ],
                                  'SDL::Mixer::MixMusic' => [
                                                              'SDL',
                                                              'SDL_mixer'
                                                            ],
                                  'SDLx::Validate' => [
                                                        'SDL'
                                                      ],
                                  'SDLx::Controller::Interface' => [
                                                                     'SDL'
                                                                   ],
                                  'SDL::Mouse' => [
                                                    'SDL'
                                                  ],
                                  'SDLx::Layer' => [
                                                     'SDL',
                                                     'SDL_image'
                                                   ],
                                  'SDL::Color' => [
                                                    'SDL'
                                                  ],
                                  'SDLx::LayerManager' => [
                                                            'SDL'
                                                          ],
                                  'SDL::GFX' => [
                                                  'SDL',
                                                  'SDL_gfx'
                                                ],
                                  'SDL::Video' => [
                                                    'SDL'
                                                  ],
                                  'SDL::Surface' => [
                                                      'SDL'
                                                    ],
                                  'SDL::AudioSpec' => [
                                                        'SDL'
                                                      ],
                                  'SDL::Cursor' => [
                                                     'SDL'
                                                   ],
                                  'SDL::Rect' => [
                                                   'SDL'
                                                 ],
                                  'SDL::Pango::Context' => [
                                                             'SDL',
                                                             'SDL_Pango'
                                                           ],
                                  'SDL::GFX::Framerate' => [
                                                             'SDL',
                                                             'SDL_gfx'
                                                           ],
                                  'SDL::Mixer::Groups' => [
                                                            'SDL',
                                                            'SDL_mixer'
                                                          ],
                                  'SDL::Event' => [
                                                    'SDL'
                                                  ],
                                  'SDL::Mixer::MixChunk' => [
                                                              'SDL',
                                                              'SDL_mixer'
                                                            ],
                                  'SDL::GFX::FPSManager' => [
                                                              'SDL',
                                                              'SDL_gfx'
                                                            ],
                                  'SDL::TTF' => [
                                                  'SDL',
                                                  'SDL_ttf'
                                                ],
                                  'SDL::Version' => [
                                                      'SDL'
                                                    ],
                                  'SDL::Image' => [
                                                    'SDL',
                                                    'SDL_image'
                                                  ],
                                  'SDL::Audio' => [
                                                    'SDL'
                                                  ],
                                  'SDL::Overlay' => [
                                                      'SDL'
                                                    ],
                                  'SDL::GFX::Rotozoom' => [
                                                            'SDL',
                                                            'SDL_gfx'
                                                          ],
                                  'SDLx::Surface' => [
                                                       'SDL',
                                                       'SDL_gfx'
                                                     ],
                                  'SDL::PixelFormat' => [
                                                          'SDL'
                                                        ],
                                  'SDL::CDTrack' => [
                                                      'SDL'
                                                    ],
                                  'SDL::Events' => [
                                                     'SDL'
                                                   ],
                                  'SDL::Time' => [
                                                   'SDL'
                                                 ]
                                },
         'libraries' => {
                          'GLU' => {
                                     'lib' => 'glu32',
                                     'define' => 'HAVE_GLU',
                                     'header' => 'GL/glu.h'
                                   },
                          'smpeg' => {
                                       'lib' => 'smpeg',
                                       'define' => 'HAVE_SMPEG',
                                       'header' => 'smpeg/smpeg.h'
                                     },
                          'SDL_gfx_rotozoom' => {
                                                  'lib' => 'SDL_gfx',
                                                  'define' => 'HAVE_SDL_GFX_ROTOZOOM',
                                                  'header' => 'SDL_rotozoom.h'
                                                },
                          'SDL_gfx_primitives' => {
                                                    'header' => 'SDL_gfxPrimitives.h',
                                                    'define' => 'HAVE_SDL_GFX_PRIMITIVES',
                                                    'lib' => 'SDL_gfx'
                                                  },
                          'GL' => {
                                    'lib' => 'opengl32',
                                    'define' => 'HAVE_GL',
                                    'header' => [
                                                  'GL/gl.h',
                                                  'GL/glext.h'
                                                ]
                                  },
                          'SDL_Pango' => {
                                           'header' => 'SDL_Pango.h',
                                           'define' => 'HAVE_SDL_PANGO',
                                           'lib' => 'SDL_Pango'
                                         },
                          'SDL_ttf' => {
                                         'header' => 'SDL_ttf.h',
                                         'define' => 'HAVE_SDL_TTF',
                                         'lib' => 'SDL_ttf'
                                       },
                          'SDL_gfx' => {
                                         'lib' => 'SDL_gfx',
                                         'define' => 'HAVE_SDL_GFX',
                                         'header' => 'SDL_gfxPrimitives.h'
                                       },
                          'SDL_gfx_framerate' => {
                                                   'header' => 'SDL_framerate.h',
                                                   'define' => 'HAVE_SDL_GFX_FRAMERATE',
                                                   'lib' => 'SDL_gfx'
                                                 },
                          'SDL_image' => {
                                           'header' => 'SDL_image.h',
                                           'define' => 'HAVE_SDL_IMAGE',
                                           'lib' => 'SDL_image'
                                         },
                          'jpeg' => {
                                      'define' => 'HAVE_JPEG',
                                      'lib' => 'jpeg',
                                      'header' => 'jpeglib.h'
                                    },
                          'tiff' => {
                                      'header' => 'tiff.h',
                                      'define' => 'HAVE_TIFF',
                                      'lib' => 'tiff'
                                    },
                          'SDL' => {
                                     'lib' => 'SDL',
                                     'define' => 'HAVE_SDL',
                                     'header' => 'SDL.h'
                                   },
                          'SDL_mixer' => {
                                           'header' => 'SDL_mixer.h',
                                           'define' => 'HAVE_SDL_MIXER',
                                           'lib' => 'SDL_mixer'
                                         },
                          'SDL_gfx_imagefilter' => {
                                                     'lib' => 'SDL_gfx',
                                                     'define' => 'HAVE_SDL_GFX_IMAGEFILTER',
                                                     'header' => 'SDL_imageFilter.h'
                                                   },
                          'png' => {
                                     'lib' => 'png',
                                     'define' => 'HAVE_PNG',
                                     'header' => 'png.h'
                                   },
                          'SDL_gfx_blitfunc' => {
                                                  'header' => 'SDL_gfxBlitFunc.h',
                                                  'define' => 'HAVE_SDL_GFX_BLITFUNC',
                                                  'lib' => 'SDL_gfx'
                                                }
                        }
       },
       {},
       {}
     ];
$x; }