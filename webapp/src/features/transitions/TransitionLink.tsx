import type { MouseEvent } from 'react';
import { Link, type LinkProps } from 'react-router-dom';
import { usePageTransition } from '../../lib/hooks/usePageTransition';

type TransitionType = 'particles' | 'morph' | 'auto' | 'none';

interface TransitionLinkProps extends Omit<LinkProps, 'to'> {
  to: string;
  transition?: TransitionType;
}

function isModifiedEvent(event: MouseEvent<HTMLAnchorElement>) {
  return event.metaKey || event.altKey || event.ctrlKey || event.shiftKey;
}

export default function TransitionLink({
  to,
  transition,
  replace,
  onClick,
  ...props
}: TransitionLinkProps) {
  const { navigate } = usePageTransition();

  const handleClick = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event);
    if (event.defaultPrevented) return;
    if (event.button !== 0 || isModifiedEvent(event)) return;

    event.preventDefault();
    void navigate(to, { replace, transition });
  };

  return (
    <Link
      to={to}
      replace={replace}
      onClick={handleClick}
      {...props}
    />
  );
}
