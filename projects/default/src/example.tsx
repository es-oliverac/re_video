/** @jsxImportSource @revideo/2d */
import {Rect, Txt, makeScene2D} from '@revideo/2d';
import {all, createRef, useScene, waitFor} from '@revideo/core';

export default makeScene2D(function* (view) {
  const rect = createRef<Rect>();
  const text = createRef<Txt>();

  const fill = useScene().variables.get('fill', 'green')();

  view.add(
    <Rect
      ref={rect}
      width={400}
      height={400}
      fill={fill}
      radius={20}
    >
      <Txt
        ref={text}
        text={'Hello Revideo!'}
        fill={'white'}
        fontSize={48}
        fontFamily={'Arial'}
      />
    </Rect>,
  );

  yield* all(
    rect().scale(1.2, 1).to(1, 1),
  );

  yield* waitFor(1);
});
