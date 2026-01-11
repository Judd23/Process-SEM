import type { MouseEvent } from 'react';
import { NavLink, type NavLinkProps } from 'react-router-dom';
import { usePageTransition } from '../../lib/hooks/usePageTransition';

type TransitionType = 'particles' | 'morph' | 'auto' | 'none';

interface TransitionNavLinkProps extends NavLinkProps {
  transition?: TransitionType;
}

function isModifiedEvent(event: MouseEvent<HTMLAnchorElement>) {
  return event.metaKey || event.altKey || event.ctrlKey || event.shiftKey;
}

export default function TransitionNavLink({
  to,
  transition,
  replace,
  onClick,
  ...props
}: TransitionNavLinkProps) {
  const { navigate } = usePageTransition();

  const handleClick = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event);
    if (event.defaultPrevented) return;
    if (event.button !== 0 || isModifiedEvent(event)) return;

    if (typeof to !== 'string') {
      return;
    }

    event.preventDefault();
    void navigate(to, { replace, transition });
  };

  return (
    <NavLink
      to={to}
      replace={replace}
      onClick={handleClick}
      {...props}
    />
  );
}
