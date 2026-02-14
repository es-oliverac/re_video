import {makeProject} from '@revideo/core';
import example from './example';

export const project = makeProject({
  name: 'project',
  scenes: [example],
  variables: {
    fill: 'green',
  },
});

export default project;
